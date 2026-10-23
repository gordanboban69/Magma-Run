import Foundation

/// Spawn instructions produced by advancing a `RunSession`.
struct TickResult: Equatable, Sendable {
    var bouldersToSpawn = 0
    var spawnEmber = false
    /// The volcano switched mood this tick (steady ↔ special).
    var moodChanged = false
    /// A lava river just started flowing this tick.
    var lavaStartedFlowing = false
    /// A drained lava river just cooled into an obsidian crust.
    var crustFormed = false

    static let none = TickResult()
}

/// What happened when something dangerous touched the hero.
enum HitOutcome: Equatable, Sendable {
    /// The hero is currently untouchable; the hit is ignored.
    case ignored
    /// Overdrive is active: the boulder shattered harmlessly and scored.
    case overdriveSmash
    /// The shield absorbed the hit and must recharge.
    case shieldAbsorbed
    /// The hero lost a heart but is still alive.
    case damaged(remainingHearts: Int)
    /// The hero lost the last heart; the run is over.
    case fatal
}

/// Telegraphed eruption phases. Each changes how the volcano behaves for a few seconds.
enum VolcanoMood: String, CaseIterable, Equatable, Sendable {
    case steady
    case fury
    case ashRain
    case emberShower

    static let specials: [VolcanoMood] = [.fury, .ashRain, .emberShower]
    static let warningDuration: TimeInterval = 1.5

    var title: String {
        switch self {
        case .steady: "Steady"
        case .fury: "Fury"
        case .ashRain: "Ash Rain"
        case .emberShower: "Ember Shower"
        }
    }

    var warningText: String {
        switch self {
        case .steady: ""
        case .fury: "The mountain rages!"
        case .ashRain: "Rocks from the sky!"
        case .emberShower: "Embers incoming!"
        }
    }

    var systemImage: String {
        switch self {
        case .steady: "mountain.2.fill"
        case .fury: "flame.fill"
        case .ashRain: "cloud.heavyrain.fill"
        case .emberShower: "sparkles"
        }
    }

    /// Multiplier for the time between boulder launches.
    var spawnIntervalMultiplier: Double {
        switch self {
        case .steady: 1
        case .fury: 0.65
        case .ashRain: 0.85
        case .emberShower: 1.4
        }
    }

    /// Fixed probability of sky-rain boulders, or `nil` to use the difficulty curve.
    var rainProbability: Double? {
        self == .ashRain ? 0.9 : nil
    }

    /// Probability that a crater boulder is aimed at the hero.
    var aimedProbability: Double {
        self == .fury ? 0.8 : 0.55
    }

    /// Multiplier for the time between ember drops.
    var emberIntervalMultiplier: Double {
        self == .emberShower ? 0.3 : 1
    }

    /// How long a special mood lasts. Steady durations are rolled by the session.
    var duration: TimeInterval {
        switch self {
        case .steady: 0
        case .fury: 6
        case .ashRain: 7
        case .emberShower: 6
        }
    }
}

/// A strip of ground that floods with lava after a warning.
struct LavaRiver: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case warning
        case flowing
    }

    static let warningDuration: TimeInterval = 1.6
    static let flowDuration: TimeInterval = 4.5
    /// Width as a fraction of the playable width.
    static let width: Double = 0.34

    /// Normalised horizontal range in `0...1`.
    var start: Double
    var end: Double
    var phase: Phase
    var remaining: TimeInterval

    func contains(_ normalizedX: Double) -> Bool {
        normalizedX >= start && normalizedX <= end
    }
}

/// The cooled strip a lava river leaves behind. Standing on it doubles score and rage.
struct ObsidianCrust: Equatable, Sendable {
    static let duration: TimeInterval = 7

    var start: Double
    var end: Double
    var remaining: TimeInterval

    func contains(_ normalizedX: Double) -> Bool {
        normalizedX >= start && normalizedX <= end
    }
}

/// What happened when the hero picked up a heart shard.
enum ShardOutcome: Equatable, Sendable {
    /// The shard was added to the set; `count` shards are now held.
    case stored(count: Int)
    /// The set was complete and restored a lost heart.
    case heartRestored
    /// The set was complete but hearts were full, so it paid out embers instead.
    case bonusEmbers(Int)
}

/// Pure, deterministic state machine for a single run.
/// The SpriteKit scene feeds it time and collisions; it answers with
/// spawn requests, score and health. Being framework-free keeps it testable.
struct RunSession: Equatable, Sendable {
    // MARK: Tunables for the signature mechanics

    static let ragePerNearMiss: Double = 0.2
    static let nearMissScore: Double = 8
    static let shockwaveScorePerBoulder: Double = 12
    static let overdriveComboLength = 6
    static let overdriveDuration: TimeInterval = 5
    static let overdriveSmashScore: Double = 15
    static let firstMoodDelay: TimeInterval = 16
    static let firstRiverDelay: TimeInterval = 10
    static let crustScoreMultiplier: Double = 2
    static let shardsPerHeart = 3
    /// Embers (before the fortune multiplier) paid for a complete set at full health.
    static let shardOverflowEmbers = 40
    /// Minimum time between two heart shard drops.
    static let shardDropCooldown: TimeInterval = 4

    let loadout: HeroLoadout

    private(set) var elapsed: TimeInterval = 0
    private(set) var score: Double = 0
    private(set) var hearts: Int
    /// Currency earned so far (already multiplied by the hero's ember value).
    private(set) var embersCollected = 0
    /// Number of individual ember pickups.
    private(set) var emberPickups = 0
    private(set) var bouldersDodged = 0
    /// Shield charge in `0...1`. Always zero when the shield is not unlocked.
    private(set) var shieldCharge: Double
    private(set) var invulnerableRemaining: TimeInterval = 0
    private(set) var nextBoulderIn: TimeInterval
    private(set) var nextEmberIn: TimeInterval
    private(set) var isOver = false

    // Mechanic 1: near-miss rage and shockwaves.
    private(set) var rage: Double = 0
    private(set) var shockwavesFired = 0
    private var shockwavePending = false

    // Mechanic 2: lava rivers.
    private(set) var lavaRiver: LavaRiver?
    private(set) var nextRiverIn: TimeInterval = RunSession.firstRiverDelay

    // Mechanic 3: ember combo and overdrive.
    private(set) var combo = 0
    private(set) var overdriveRemaining: TimeInterval = 0
    private(set) var overdrivesTriggered = 0

    // Mechanic 4: volcano moods.
    private(set) var mood: VolcanoMood = .steady
    /// Set while the warning banner should show, before `mood` switches.
    private(set) var upcomingMood: VolcanoMood?
    private(set) var moodRemaining: TimeInterval = RunSession.firstMoodDelay
    private(set) var moodWarningRemaining: TimeInterval = 0

    // Mechanic 5: obsidian crust left by drained rivers.
    private(set) var crust: ObsidianCrust?
    /// Hero position in `0...1`, reported by the scene every frame.
    private(set) var heroNormalizedX: Double = 0.5
    private(set) var crustTime: TimeInterval = 0

    // Mechanic 6: heart shards from smashed hot boulders.
    /// Shards held toward the next complete set, in `0..<shardsPerHeart`.
    private(set) var heartShards = 0
    private(set) var shardsCollected = 0
    private(set) var heartsRestored = 0
    private(set) var shardCooldownRemaining: TimeInterval = 0

    private var rng: SeededGenerator

    init(loadout: HeroLoadout, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.loadout = loadout
        hearts = loadout.maxHearts
        shieldCharge = loadout.shieldRecharge == nil ? 0 : 1
        // A short breather so the player can get a feel for steering before the first rock.
        nextBoulderIn = GameBalance.initialSpawnInterval * 1.4
        nextEmberIn = 1.5
        rng = SeededGenerator(seed: seed)
    }

    var hasShield: Bool { loadout.shieldRecharge != nil }
    var isShieldReady: Bool { hasShield && shieldCharge >= 1 }
    var isInvulnerable: Bool { invulnerableRemaining > 0 }
    var isOverdrive: Bool { overdriveRemaining > 0 }
    var isShockwaveReady: Bool { shockwavePending }
    var displayScore: Int { Int(score) }
    var isOnCrust: Bool { crust?.contains(heroNormalizedX) ?? false }

    /// Currency awarded for the next ember pickup.
    var currentEmberValue: Int { loadout.emberValue * (isOverdrive ? 2 : 1) }

    // MARK: - Time

    /// Advances the simulation clock and returns what should be spawned.
    mutating func advance(by dt: TimeInterval) -> TickResult {
        guard !isOver, dt > 0 else { return .none }

        elapsed += dt
        let crustBonus = isOnCrust ? Self.crustScoreMultiplier : 1
        score += GameBalance.scorePerSecond * GameBalance.scoreMultiplier(at: elapsed) * crustBonus * dt
        if isOnCrust {
            crustTime += dt
        }
        invulnerableRemaining = max(0, invulnerableRemaining - dt)
        overdriveRemaining = max(0, overdriveRemaining - dt)
        shardCooldownRemaining = max(0, shardCooldownRemaining - dt)

        if let recharge = loadout.shieldRecharge, shieldCharge < 1 {
            shieldCharge = min(1, shieldCharge + dt / recharge)
        }

        var result = TickResult()
        advanceCrust(by: dt)
        advanceMood(by: dt, result: &result)
        advanceLavaRiver(by: dt, result: &result)

        nextBoulderIn -= dt
        while nextBoulderIn <= 0 {
            result.bouldersToSpawn += 1
            nextBoulderIn += GameBalance.spawnInterval(at: elapsed) * mood.spawnIntervalMultiplier
        }

        nextEmberIn -= dt
        if nextEmberIn <= 0 {
            result.spawnEmber = true
            nextEmberIn = loadout.emberInterval * mood.emberIntervalMultiplier
        }

        return result
    }

    private mutating func advanceMood(by dt: TimeInterval, result: inout TickResult) {
        if let upcoming = upcomingMood {
            moodWarningRemaining -= dt
            if moodWarningRemaining <= 0 {
                mood = upcoming
                upcomingMood = nil
                moodWarningRemaining = 0
                moodRemaining = upcoming.duration
                result.moodChanged = true
            }
            return
        }

        moodRemaining -= dt
        guard moodRemaining <= 0 else { return }

        if mood == .steady {
            let index = Int(rng.next() % UInt64(VolcanoMood.specials.count))
            upcomingMood = VolcanoMood.specials[index]
            moodWarningRemaining = VolcanoMood.warningDuration
            moodRemaining = 0
        } else {
            mood = .steady
            moodRemaining = 9 + Double(rng.next() % 6) // 9...14 seconds of calm
            result.moodChanged = true
        }
    }

    private mutating func advanceLavaRiver(by dt: TimeInterval, result: inout TickResult) {
        if var river = lavaRiver {
            river.remaining -= dt
            if river.remaining <= 0 {
                switch river.phase {
                case .warning:
                    river.phase = .flowing
                    river.remaining = LavaRiver.flowDuration
                    result.lavaStartedFlowing = true
                    lavaRiver = river
                case .flowing:
                    lavaRiver = nil
                    crust = ObsidianCrust(start: river.start, end: river.end, remaining: ObsidianCrust.duration)
                    result.crustFormed = true
                    nextRiverIn = 12 + Double(rng.next() % 9) // 12...20 seconds
                }
            } else {
                lavaRiver = river
            }
            return
        }

        nextRiverIn -= dt
        if nextRiverIn <= 0 {
            let maxStart = 1 - LavaRiver.width
            let start = Double(rng.next() % 1000) / 1000 * maxStart
            lavaRiver = LavaRiver(start: start, end: start + LavaRiver.width, phase: .warning, remaining: LavaRiver.warningDuration)
        }
    }

    private mutating func advanceCrust(by dt: TimeInterval) {
        guard var current = crust else { return }
        current.remaining -= dt
        crust = current.remaining > 0 ? current : nil
    }

    /// Records where the hero stands so the crust bonus can be applied.
    mutating func updateHeroPosition(normalizedX: Double) {
        heroNormalizedX = min(max(normalizedX, 0), 1)
    }

    // MARK: - Damage

    /// Applies a boulder collision and reports the consequence.
    mutating func registerBoulderHit() -> HitOutcome {
        guard !isOver else { return .ignored }
        if isOverdrive {
            score += Self.overdriveSmashScore
            bouldersDodged += 1
            return .overdriveSmash
        }
        return applyDamage()
    }

    /// True when the hero, at the given normalised x, is standing in flowing lava.
    func isLavaBurning(atNormalizedX x: Double) -> Bool {
        guard let river = lavaRiver, river.phase == .flowing else { return false }
        return river.contains(x)
    }

    /// Applies lava damage. Overdrive does not protect from lava; invulnerability does.
    mutating func registerLavaBurn() -> HitOutcome {
        guard !isOver else { return .ignored }
        return applyDamage()
    }

    private mutating func applyDamage() -> HitOutcome {
        guard !isInvulnerable else { return .ignored }

        if isShieldReady {
            shieldCharge = 0
            invulnerableRemaining = GameBalance.shieldGraceDuration
            return .shieldAbsorbed
        }

        hearts -= 1
        combo = 0
        if hearts <= 0 {
            hearts = 0
            isOver = true
            return .fatal
        }

        invulnerableRemaining = GameBalance.invulnerabilityDuration
        return .damaged(remainingHearts: hearts)
    }

    // MARK: - Rewards

    /// Awards currency and score for touching an ember; long streaks trigger overdrive.
    mutating func registerEmberPickup() {
        guard !isOver else { return }
        emberPickups += 1
        combo += 1
        embersCollected += currentEmberValue
        score += Double(GameBalance.scorePerEmber)
        if combo % Self.overdriveComboLength == 0 {
            overdriveRemaining = Self.overdriveDuration
            overdrivesTriggered += 1
        }
    }

    /// Awards score for a boulder that passed the hero without hitting.
    mutating func registerDodge() {
        guard !isOver else { return }
        bouldersDodged += 1
        score += Double(GameBalance.scorePerDodge)
    }

    /// A boulder passed within a hair of the hero: builds rage toward a shockwave.
    mutating func registerNearMiss() {
        guard !isOver else { return }
        let crustBonus = isOnCrust ? Self.crustScoreMultiplier : 1
        score += Self.nearMissScore * crustBonus
        rage = min(1, rage + Self.ragePerNearMiss * crustBonus)
        if rage >= 1 {
            shockwavePending = true
        }
    }

    /// Returns `true` once when a full rage bar should discharge as a shockwave.
    mutating func consumeShockwave() -> Bool {
        guard shockwavePending, !isOver else { return false }
        shockwavePending = false
        rage = 0
        shockwavesFired += 1
        return true
    }

    /// Scores the boulders destroyed by a shockwave.
    mutating func registerShockwaveSmash(count: Int) {
        guard !isOver, count > 0 else { return }
        score += Self.shockwaveScorePerBoulder * Double(count)
        bouldersDodged += count
    }

    /// A hot boulder was destroyed by overdrive or a shockwave.
    /// Returns `true` when it should drop a heart shard (rate-limited by a cooldown).
    mutating func registerHotSmash() -> Bool {
        guard !isOver, shardCooldownRemaining <= 0 else { return false }
        shardCooldownRemaining = Self.shardDropCooldown
        return true
    }

    /// Adds a heart shard; a complete set heals one heart or pays embers at full health.
    mutating func registerShardPickup() -> ShardOutcome {
        guard !isOver else { return .stored(count: heartShards) }
        shardsCollected += 1
        heartShards += 1
        guard heartShards >= Self.shardsPerHeart else { return .stored(count: heartShards) }

        heartShards = 0
        if hearts < loadout.maxHearts {
            hearts += 1
            heartsRestored += 1
            return .heartRestored
        }
        let bonus = Self.shardOverflowEmbers * loadout.emberValue
        embersCollected += bonus
        return .bonusEmbers(bonus)
    }

    /// Snapshot used to persist the finished run.
    var summary: RunSummary {
        RunSummary(
            score: displayScore,
            embersCollected: embersCollected,
            duration: elapsed,
            bouldersDodged: bouldersDodged,
            heroID: loadout.skin.rawValue,
            shockwaves: shockwavesFired,
            overdrives: overdrivesTriggered,
            heartShards: shardsCollected,
            crustTime: crustTime
        )
    }
}
