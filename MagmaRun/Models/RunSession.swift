import Foundation

/// Spawn instructions produced by advancing a `RunSession`.
struct TickResult: Equatable, Sendable {
    var bouldersToSpawn = 0
    var spawnEmber = false

    static let none = TickResult()
}

/// What happened when a boulder touched the hero.
enum HitOutcome: Equatable, Sendable {
    /// The hero is currently untouchable; the hit is ignored.
    case ignored
    /// The shield absorbed the hit and must recharge.
    case shieldAbsorbed
    /// The hero lost a heart but is still alive.
    case damaged(remainingHearts: Int)
    /// The hero lost the last heart; the run is over.
    case fatal
}

/// Pure, deterministic state machine for a single run.
/// The SpriteKit scene feeds it time and collisions; it answers with
/// spawn requests, score and health. Being framework-free keeps it testable.
struct RunSession: Equatable, Sendable {
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

    init(loadout: HeroLoadout) {
        self.loadout = loadout
        hearts = loadout.maxHearts
        shieldCharge = loadout.shieldRecharge == nil ? 0 : 1
        nextBoulderIn = GameBalance.initialSpawnInterval * 0.8
        nextEmberIn = 1.5
    }

    var hasShield: Bool { loadout.shieldRecharge != nil }
    var isShieldReady: Bool { hasShield && shieldCharge >= 1 }
    var isInvulnerable: Bool { invulnerableRemaining > 0 }
    var displayScore: Int { Int(score) }

    /// Advances the simulation clock and returns what should be spawned.
    mutating func advance(by dt: TimeInterval) -> TickResult {
        guard !isOver, dt > 0 else { return .none }

        elapsed += dt
        score += GameBalance.scorePerSecond * GameBalance.scoreMultiplier(at: elapsed) * dt
        invulnerableRemaining = max(0, invulnerableRemaining - dt)

        if let recharge = loadout.shieldRecharge, shieldCharge < 1 {
            shieldCharge = min(1, shieldCharge + dt / recharge)
        }

        var result = TickResult()

        nextBoulderIn -= dt
        while nextBoulderIn <= 0 {
            result.bouldersToSpawn += 1
            nextBoulderIn += GameBalance.spawnInterval(at: elapsed)
        }

        nextEmberIn -= dt
        if nextEmberIn <= 0 {
            result.spawnEmber = true
            nextEmberIn = loadout.emberInterval
        }

        return result
    }

    /// Applies a boulder collision and reports the consequence.
    mutating func registerBoulderHit() -> HitOutcome {
        guard !isOver, !isInvulnerable else { return .ignored }

        if isShieldReady {
            shieldCharge = 0
            invulnerableRemaining = GameBalance.shieldGraceDuration
            return .shieldAbsorbed
        }

        hearts -= 1
        if hearts <= 0 {
            hearts = 0
            isOver = true
            return .fatal
        }

        invulnerableRemaining = GameBalance.invulnerabilityDuration
        return .damaged(remainingHearts: hearts)
    }

    /// Awards currency and score for touching an ember.
    mutating func registerEmberPickup() {
        guard !isOver else { return }
        emberPickups += 1
        embersCollected += loadout.emberValue
        score += Double(GameBalance.scorePerEmber)
    }

    /// Awards score for a boulder that passed the hero without hitting.
    mutating func registerDodge() {
        guard !isOver else { return }
        bouldersDodged += 1
        score += Double(GameBalance.scorePerDodge)
    }

    /// Snapshot used to persist the finished run.
    var summary: RunSummary {
        RunSummary(
            score: displayScore,
            embersCollected: embersCollected,
            duration: elapsed,
            bouldersDodged: bouldersDodged,
            heroID: loadout.skin.rawValue
        )
    }
}
