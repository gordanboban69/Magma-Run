import SpriteKit

/// Receives gameplay updates from `VolcanoScene` on the main actor.
@MainActor
protocol VolcanoSceneDelegate: AnyObject {
    func scene(_ scene: VolcanoScene, didUpdate hud: GameHUDState)
    func scene(_ scene: VolcanoScene, didRegister event: GameEvent)
    func scene(_ scene: VolcanoScene, didFinishWith summary: RunSummary)
}

/// The SpriteKit scene for one run: an erupting volcano hurling boulders at the hero.
/// Gameplay rules live in `RunSession`; this class handles rendering, physics and input.
@MainActor
final class VolcanoScene: SKScene {
    weak var gameDelegate: VolcanoSceneDelegate?

    private(set) var session: RunSession
    private(set) var isRunning = false

    /// How the player steers. Can be changed while the scene is alive.
    var controlScheme: ControlScheme
    /// Direction from the on-screen buttons: `-1`, `0` or `1`.
    var steeringDirection: CGFloat = 0

    private let world = SKNode()
    private var hero: HeroNode
    private var boulders: [BoulderNode] = []
    private var embers: [EmberNode] = []
    private var shards: [HeartShardNode] = []
    private var riverNode: LavaRiverNode?
    private var crustNode: CrustNode?
    private var craterBurst: SKSpriteNode?
    private var lastBurstTime: TimeInterval = 0

    private var background: SKSpriteNode?
    private var craterGlow: SKSpriteNode?
    private var scenery: [SKNode] = []
    private var layout: SceneryBuilder.Layout
    private var lastUpdateTime: TimeInterval?
    private var hudAccumulator: TimeInterval = 0
    private var targetX: CGFloat?
    private var lastSize: CGSize = .zero
    private var hasFinished = false
    private var lastOverdriveCount = 0

    private static let hudInterval: TimeInterval = 0.1
    /// Extra horizontal slack (points) that still counts as a near miss.
    private static let nearMissMargin: CGFloat = 26

    init(size: CGSize, loadout: HeroLoadout, controlScheme: ControlScheme) {
        session = RunSession(loadout: loadout)
        hero = HeroNode(skin: loadout.skin)
        layout = SceneryBuilder.layout(for: size)
        self.controlScheme = controlScheme
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("VolcanoScene does not support NSCoding")
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.04, green: 0.02, blue: 0.06, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -5.5)
        physicsWorld.contactDelegate = self
        view.ignoresSiblingOrder = true

        if world.parent == nil {
            addChild(world)
        }
        rebuildScenery(for: view.bounds.size == .zero ? size : view.bounds.size)
        hero.setShieldVisible(session.isShieldReady, animated: false)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size != lastSize, size.width > 0, size.height > 0 else { return }
        rebuildScenery(for: size)
    }

    private func rebuildScenery(for newSize: CGSize) {
        lastSize = newSize
        layout = SceneryBuilder.layout(for: newSize)

        background?.removeFromParent()
        let sky = SceneryBuilder.makeSky(for: session.mood, size: newSize)
        addChild(sky)
        background = sky

        scenery.forEach { $0.removeFromParent() }
        let glow = SceneryBuilder.makeCraterGlow(at: layout.craterPoint, sceneSize: newSize)
        craterGlow = glow
        let burst = SceneryBuilder.makeCraterBurst(at: layout.craterPoint)
        craterBurst = burst
        scenery = [
            glow,
            SceneryBuilder.makeMountain(size: newSize, crater: layout.craterPoint),
            SceneryBuilder.makeCraterSmoke(at: layout.craterPoint),
            SceneryBuilder.makeSparks(at: layout.craterPoint),
            burst,
            SceneryBuilder.makeAsh(size: newSize),
            SceneryBuilder.makeGround(size: newSize, groundTop: layout.groundTop)
        ]
        scenery.forEach { world.addChild($0) }
        applyMoodTint(animated: false)

        if hero.parent == nil {
            hero.position = CGPoint(x: newSize.width / 2, y: layout.heroY)
            hero.zPosition = SceneLayer.hero
            world.addChild(hero)
        } else {
            let clampedX = min(max(hero.position.x, horizontalMargin), newSize.width - horizontalMargin)
            hero.position = CGPoint(x: clampedX, y: layout.heroY)
        }

        // Rebuild the river and crust for the new width if one is active.
        riverNode?.removeFromParent()
        riverNode = nil
        crustNode?.removeFromParent()
        crustNode = nil
        syncRiverNode()
        syncCrustNode()
        targetX = nil
    }

    /// Starts the eruption. Before this the scene idles with the hero in place.
    func startRun() {
        guard !isRunning, !session.isOver else { return }
        isRunning = true
        lastUpdateTime = nil
        publishHUD()
    }

    /// Freezes or resumes the simulation, physics and actions. Idempotent.
    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        isPaused = suspended
        physicsWorld.speed = suspended ? 0 : 1
        if !suspended {
            // Forget the stale timestamp so the first frame after resuming is a small step.
            lastUpdateTime = nil
            steeringDirection = 0
            targetX = nil
        }
    }

    private var isSuspended = false

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard isRunning, !isSuspended, !session.isOver else { return }
        guard let last = lastUpdateTime else { return }

        // Clamp so a pause or hitch never produces a giant simulation step.
        let dt = min(max(currentTime - last, 0), 1.0 / 20.0)
        guard dt > 0 else { return }

        session.updateHeroPosition(normalizedX: Double(hero.position.x / max(size.width, 1)))
        let tick = session.advance(by: dt)
        for _ in 0..<tick.bouldersToSpawn {
            spawnBoulder()
        }
        if tick.spawnEmber {
            spawnEmber()
        }
        if tick.moodChanged {
            applyMoodTint(animated: true)
            gameDelegate?.scene(self, didRegister: .moodChanged(session.mood))
        }
        if tick.lavaStartedFlowing {
            gameDelegate?.scene(self, didRegister: .lavaStarted)
        }
        if tick.crustFormed {
            gameDelegate?.scene(self, didRegister: .crustFormed)
        }

        moveHero(dt: dt)
        applyMagnet()
        cullBoulders()
        cullEmbers()
        updateShards()
        syncRiverNode()
        syncCrustNode()
        checkLava()
        fireShockwaveIfReady()

        hero.setOverdrive(session.isOverdrive)
        if session.overdrivesTriggered > lastOverdriveCount {
            lastOverdriveCount = session.overdrivesTriggered
            gameDelegate?.scene(self, didRegister: .overdriveStarted)
        }
        if session.hasShield {
            hero.setShieldVisible(session.isShieldReady)
        }

        hudAccumulator += dt
        if hudAccumulator >= Self.hudInterval {
            hudAccumulator = 0
            publishHUD()
        }
    }

    private var horizontalMargin: CGFloat { HeroNode.bodyRadius + 6 }

    /// Scales movement so wide screens stay fair.
    private var effectiveMoveSpeed: CGFloat {
        let widthFactor = min(max(size.width / 390, 1), 1.7)
        return CGFloat(session.loadout.moveSpeed) * widthFactor
    }

    private func moveHero(dt: TimeInterval) {
        let speed = effectiveMoveSpeed
        var dx: CGFloat = 0

        switch controlScheme {
        case .drag:
            if let targetX {
                let diff = targetX - hero.position.x
                dx = min(abs(diff), speed * dt) * (diff < 0 ? -1 : 1)
            }
        case .buttons:
            dx = steeringDirection * speed * dt
        }

        let newX = min(max(hero.position.x + dx, horizontalMargin), size.width - horizontalMargin)
        let appliedDx = newX - hero.position.x
        hero.position.x = newX
        hero.setLean(dt > 0 ? appliedDx / (speed * dt) : 0)
    }

    private func applyMagnet() {
        let radius = CGFloat(session.loadout.magnetRadius)
        guard radius > 0 else { return }
        for ember in embers where !ember.isCollected {
            let delta = CGPoint(x: hero.position.x - ember.position.x, y: hero.position.y - ember.position.y)
            let distance = hypot(delta.x, delta.y)
            guard distance < radius, distance > 1, let body = ember.physicsBody else { continue }
            let pull: CGFloat = 520
            body.velocity = CGVector(dx: delta.x / distance * pull, dy: delta.y / distance * pull)
        }
    }

    // MARK: - Signature mechanics

    /// Lava rivers: keep the ground node in sync with the session's river state.
    private func syncRiverNode() {
        guard let river = session.lavaRiver else {
            if let node = riverNode {
                node.drain()
                riverNode = nil
            }
            return
        }

        let width = CGFloat(river.end - river.start) * size.width
        if riverNode == nil {
            let node = LavaRiverNode(width: width, groundHeight: layout.groundTop)
            node.position = CGPoint(x: CGFloat(river.start) * size.width, y: 0)
            world.addChild(node)
            riverNode = node
        }
        if river.phase == .flowing, riverNode?.phase == .warning {
            riverNode?.startFlowing(width: width)
        }
    }

    /// Obsidian crust: mirror the cooled strip a drained river leaves behind.
    private func syncCrustNode() {
        guard let crust = session.crust else {
            if let node = crustNode {
                node.crumble()
                crustNode = nil
            }
            return
        }
        if crustNode == nil {
            let node = CrustNode(width: CGFloat(crust.end - crust.start) * size.width, groundHeight: layout.groundTop)
            node.position = CGPoint(x: CGFloat(crust.start) * size.width, y: 0)
            world.addChild(node)
            crustNode = node
        }
        crustNode?.setActive(session.isOnCrust)
    }

    /// Heart shards: drop one where a hot boulder was smashed, if the cooldown allows.
    private func dropShardIfEarned(from boulder: BoulderNode) {
        guard boulder.isHot, session.registerHotSmash() else { return }
        let shard = HeartShardNode()
        shard.position = CGPoint(
            x: min(max(boulder.position.x, horizontalMargin), size.width - horizontalMargin),
            y: max(boulder.position.y, layout.heroY)
        )
        shard.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -40...40), dy: 160)
        world.addChild(shard)
        shards.append(shard)
    }

    private func updateShards() {
        shards.removeAll { $0.parent == nil || $0.isCollected }
        for shard in shards {
            shard.settle(onGroundAt: layout.heroY)
        }
    }

    /// Lava rivers: burn the hero while standing in flowing lava.
    private func checkLava() {
        let normalizedX = Double(hero.position.x / max(size.width, 1))
        guard session.isLavaBurning(atNormalizedX: normalizedX) else { return }
        let outcome = session.registerLavaBurn()
        handle(outcome: outcome)
    }

    /// Rage: a full bar detonates and clears nearby boulders.
    private func fireShockwaveIfReady() {
        guard session.consumeShockwave() else { return }
        let radius = max(size.width, size.height) * 0.75
        var smashed = 0
        for boulder in boulders where boulder.parent != nil && boulder.physicsBody != nil {
            let distance = hypot(boulder.position.x - hero.position.x, boulder.position.y - hero.position.y)
            if distance <= radius {
                dropShardIfEarned(from: boulder)
                boulder.shatter()
                smashed += 1
            }
        }
        boulders.removeAll { $0.parent == nil || $0.physicsBody == nil }
        session.registerShockwaveSmash(count: smashed)
        hero.playShockwave(radius: radius)
        shakeWorld(intensity: 14)
        gameDelegate?.scene(self, didRegister: .shockwave)
        publishHUD()
    }

    /// Moods: swap the painted sky and tint the crater glow to telegraph the current phase.
    private func applyMoodTint(animated: Bool) {
        if animated, let old = background {
            let sky = SceneryBuilder.makeSky(for: session.mood, size: size)
            sky.alpha = 0
            sky.zPosition = SceneLayer.background + 1
            addChild(sky)
            background = sky
            sky.run(.sequence([.fadeIn(withDuration: 0.8), .run { sky.zPosition = SceneLayer.background }]))
            old.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
            playCraterBurst(force: true)
        }
        guard let craterGlow else { return }
        let color: UIColor
        switch session.mood {
        case .steady: color = UIColor(red: 1.0, green: 0.40, blue: 0.10, alpha: 1)
        case .fury: color = UIColor(red: 1.0, green: 0.12, blue: 0.08, alpha: 1)
        case .ashRain: color = UIColor(red: 0.75, green: 0.62, blue: 0.70, alpha: 1)
        case .emberShower: color = UIColor(red: 1.0, green: 0.78, blue: 0.25, alpha: 1)
        }
        if animated {
            craterGlow.run(.colorize(with: color, colorBlendFactor: 1, duration: 0.6))
        } else {
            craterGlow.color = color
        }
    }

    // MARK: - Spawning

    private func spawnBoulder() {
        let multiplier = CGFloat(GameBalance.speedMultiplier(at: session.elapsed))
        let rainChance = session.mood.rainProbability ?? GameBalance.rainProbability(at: session.elapsed)
        let isRain = Double.random(in: 0..<1) < rainChance
        let radius = CGFloat.random(in: 15...31)
        let boulder = BoulderNode(radius: radius, variant: Int.random(in: 0..<4), isHot: Double.random(in: 0..<1) < 0.25)
        guard let body = boulder.physicsBody else { return }

        if isRain {
            boulder.position = CGPoint(
                x: CGFloat.random(in: horizontalMargin...(size.width - horizontalMargin)),
                y: size.height + radius + 10
            )
            body.affectedByGravity = false
            body.velocity = CGVector(
                dx: CGFloat.random(in: -40...40),
                dy: -CGFloat.random(in: 190...320) * multiplier
            )
        } else {
            let crater = layout.craterPoint
            boulder.position = CGPoint(x: crater.x + CGFloat.random(in: -14...14), y: crater.y)
            body.affectedByGravity = true
            playCraterBurst(force: false)

            let launchSpeed = CGFloat.random(in: 240...500) * multiplier
            // Aim ramps in over the first half minute so new players can find their feet.
            let aimRamp = 0.35 + 0.65 * min(1, session.elapsed / 30)
            let isAimed = Double.random(in: 0..<1) < session.mood.aimedProbability * aimRamp
            let targetX: CGFloat = isAimed
                ? hero.position.x + CGFloat.random(in: -90...90)
                : CGFloat.random(in: horizontalMargin...(size.width - horizontalMargin))

            // Solve the ballistic flight time down to the hero's height, then pick
            // the horizontal speed that lands the boulder near the target.
            let gravity = abs(physicsWorld.gravity.dy) * 150
            let drop = max(crater.y - hero.position.y, 1)
            let flightTime = (launchSpeed + sqrt(launchSpeed * launchSpeed + 2 * gravity * drop)) / gravity
            let maxHorizontal = 260 * multiplier
            let vx = min(max((targetX - crater.x) / flightTime, -maxHorizontal), maxHorizontal)
            body.velocity = CGVector(dx: vx, dy: launchSpeed)
        }

        body.angularVelocity = CGFloat.random(in: -5...5)
        world.addChild(boulder)
        boulders.append(boulder)
    }

    /// Plays the painted lava splash over the crater, at most a few times per second.
    private func playCraterBurst(force: Bool) {
        guard let craterBurst else { return }
        let now = session.elapsed
        guard force || now - lastBurstTime > 0.6 else { return }
        lastBurstTime = now
        craterBurst.removeAction(forKey: "burst")
        craterBurst.setScale(CGFloat.random(in: 0.85...1.15))
        craterBurst.run(SceneryBuilder.burstAction, withKey: "burst")
    }

    private func spawnEmber() {
        let ember = EmberNode()
        let crater = layout.craterPoint
        let fromCrater = Bool.random()
        if fromCrater {
            ember.position = CGPoint(x: crater.x, y: crater.y + 10)
            ember.physicsBody?.affectedByGravity = true
            ember.physicsBody?.velocity = CGVector(
                dx: CGFloat.random(in: -size.width * 0.35...size.width * 0.35),
                dy: CGFloat.random(in: 380...560)
            )
            ember.physicsBody?.linearDamping = 0.9
        } else {
            ember.position = CGPoint(
                x: CGFloat.random(in: horizontalMargin...(size.width - horizontalMargin)),
                y: size.height + 20
            )
            ember.physicsBody?.velocity = CGVector(dx: 0, dy: -CGFloat.random(in: 90...140))
        }
        world.addChild(ember)
        embers.append(ember)
    }

    // MARK: - Cleanup

    private func cullBoulders() {
        let dodgeLine = hero.position.y - HeroNode.bodyRadius
        boulders.removeAll { boulder in
            if boulder.parent == nil { return true }
            if !boulder.hasBeenDodged, boulder.position.y + boulder.radius < dodgeLine {
                boulder.hasBeenDodged = true
                let horizontalGap = abs(boulder.position.x - hero.position.x) - boulder.radius - HeroNode.bodyRadius
                if horizontalGap <= Self.nearMissMargin {
                    session.registerNearMiss()
                } else {
                    session.registerDodge()
                }
            }
            if boulder.hasBeenDodged, boulder.position.y - boulder.radius * 0.4 < layout.groundTop {
                boulder.shatter()
                return true
            }
            let outOfBounds = boulder.position.y < -boulder.radius * 2 - 40
                || boulder.position.x < -size.width * 0.3
                || boulder.position.x > size.width * 1.3
            if outOfBounds {
                boulder.removeFromParent()
                return true
            }
            return false
        }
    }

    private func cullEmbers() {
        embers.removeAll { ember in
            if ember.parent == nil { return true }
            if ember.position.y < -40 || ember.position.x < -60 || ember.position.x > size.width + 60 {
                ember.removeFromParent()
                return true
            }
            return false
        }
    }

    // MARK: - Collisions

    private func handleBoulderHit(_ boulder: BoulderNode) {
        guard boulder.physicsBody != nil else { return }
        let outcome = session.registerBoulderHit()
        if outcome == .overdriveSmash {
            dropShardIfEarned(from: boulder)
        }
        boulder.shatter()
        handle(outcome: outcome)
    }

    private func handle(outcome: HitOutcome) {
        switch outcome {
        case .ignored:
            return
        case .overdriveSmash:
            shakeWorld(intensity: 4)
        case .shieldAbsorbed:
            hero.playShieldBreak()
            shakeWorld(intensity: 6)
            gameDelegate?.scene(self, didRegister: .shieldAbsorbed)
        case .damaged:
            hero.playDamageBlink(duration: GameBalance.invulnerabilityDuration)
            shakeWorld(intensity: 10)
            gameDelegate?.scene(self, didRegister: .damaged)
        case .fatal:
            finishRun()
        }
        publishHUD()
    }

    private func handleEmberPickup(_ ember: EmberNode) {
        guard !ember.isCollected else { return }
        ember.collect()
        session.registerEmberPickup()
        gameDelegate?.scene(self, didRegister: .emberCollected)
        publishHUD()
    }

    private func handleShardPickup(_ shard: HeartShardNode) {
        guard !shard.isCollected else { return }
        shard.collect()
        switch session.registerShardPickup() {
        case .stored:
            gameDelegate?.scene(self, didRegister: .shardCollected)
        case .heartRestored:
            hero.playHeal()
            gameDelegate?.scene(self, didRegister: .heartRestored)
        case .bonusEmbers:
            hero.playHeal()
            gameDelegate?.scene(self, didRegister: .emberCollected)
        }
        publishHUD()
    }

    private func finishRun() {
        guard !hasFinished else { return }
        hasFinished = true
        isRunning = false
        shakeWorld(intensity: 16)
        gameDelegate?.scene(self, didRegister: .defeated)

        let summary = session.summary
        hero.playDefeat { [weak self] in
            guard let self else { return }
            self.gameDelegate?.scene(self, didFinishWith: summary)
        }
    }

    private func shakeWorld(intensity: CGFloat) {
        world.removeAction(forKey: "shake")
        var actions: [SKAction] = []
        var amplitude = intensity
        for _ in 0..<5 {
            let dx = CGFloat.random(in: -amplitude...amplitude)
            let dy = CGFloat.random(in: -amplitude...amplitude)
            actions.append(.moveBy(x: dx, y: dy, duration: 0.03))
            actions.append(.moveBy(x: -dx, y: -dy, duration: 0.03))
            amplitude *= 0.6
        }
        actions.append(.move(to: .zero, duration: 0.02))
        world.run(.sequence(actions), withKey: "shake")
    }

    private func publishHUD() {
        gameDelegate?.scene(self, didUpdate: GameHUDState(session: session))
    }

    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTarget(from: touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateTarget(from: touches)
    }

    private func updateTarget(from touches: Set<UITouch>) {
        // Ignore touches during the countdown and pause so the hero does not jump afterwards.
        guard isRunning, !isSuspended, controlScheme == .drag, let touch = touches.first else { return }
        targetX = touch.location(in: self).x
    }
}

// MARK: - SKPhysicsContactDelegate

extension VolcanoScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        guard isRunning else { return }
        let nodes = [contact.bodyA.node, contact.bodyB.node]
        guard nodes.contains(where: { $0 is HeroNode }) else { return }

        if let boulder = nodes.compactMap({ $0 as? BoulderNode }).first {
            handleBoulderHit(boulder)
        } else if let ember = nodes.compactMap({ $0 as? EmberNode }).first {
            handleEmberPickup(ember)
        } else if let shard = nodes.compactMap({ $0 as? HeartShardNode }).first {
            handleShardPickup(shard)
        }
    }
}
