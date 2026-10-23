import SpriteKit

/// The player's character: a four-frame run cycle from the generated art,
/// with a shield bubble, an ember trail and overdrive / damage effects.
@MainActor
final class HeroNode: SKNode {
    static let bodyRadius: CGFloat = 22

    /// Painted frames are 90 × 110 pt with the feet at y = 104 pt from the top.
    private static let frameSize = CGSize(width: 90, height: 110)
    private static let feetFromTop: CGFloat = 104
    private static let spriteScale: CGFloat = 0.78
    /// Where the feet sit relative to the node origin (the physics body centre is at y = 4).
    private static let feetY: CGFloat = -26

    private let sprite: SKSpriteNode
    private let aura: SKSpriteNode
    private let shadow: SKSpriteNode
    private let shieldBubble: SKSpriteNode
    private let trail: SKEmitterNode
    private let runFrames: [SKTexture]
    private let glowColor: UIColor

    init(skin: HeroSkin) {
        glowColor = skin.glow.uiColor
        runFrames = TextureFactory.frames(Art.heroRunFrames(skin))

        sprite = SKSpriteNode(texture: runFrames.first)
        sprite.size = CGSize(width: Self.frameSize.width * Self.spriteScale, height: Self.frameSize.height * Self.spriteScale)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 1 - Self.feetFromTop / Self.frameSize.height)
        sprite.position = CGPoint(x: 0, y: Self.feetY)

        aura = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        aura.size = CGSize(width: 96, height: 96)
        aura.position = CGPoint(x: 0, y: 6)
        aura.color = skin.glow.uiColor
        aura.colorBlendFactor = 1
        aura.blendMode = .add
        aura.alpha = 0.22
        aura.zPosition = -2

        shadow = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        shadow.size = CGSize(width: 56, height: 12)
        shadow.position = CGPoint(x: 0, y: Self.feetY + 1)
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.alpha = 0.6
        shadow.zPosition = -3

        shieldBubble = SKSpriteNode(texture: TextureFactory.named(Art.shieldBubble))
        shieldBubble.size = CGSize(width: 86, height: 86)
        shieldBubble.position = CGPoint(x: 0, y: 4)
        shieldBubble.alpha = 0
        shieldBubble.zPosition = 2

        trail = SKEmitterNode()
        trail.particleTexture = TextureFactory.softCircle(diameter: 32)
        trail.particleBirthRate = 30
        trail.particleLifetime = 0.5
        trail.particleLifetimeRange = 0.2
        trail.particlePositionRange = CGVector(dx: 16, dy: 2)
        trail.particleSpeed = 50
        trail.particleSpeedRange = 25
        trail.emissionAngle = .pi / 2
        trail.emissionAngleRange = 0.8
        trail.particleScale = 0.4
        trail.particleScaleSpeed = -0.7
        trail.particleAlpha = 0.8
        trail.particleAlphaSpeed = -1.6
        trail.particleColor = glowColor
        trail.particleColorBlendFactor = 1
        trail.particleBlendMode = .add
        trail.position = CGPoint(x: 0, y: Self.feetY + 2)
        trail.zPosition = -1

        super.init()

        addChild(shadow)
        addChild(aura)
        addChild(trail)
        addChild(sprite)
        addChild(shieldBubble)

        let physics = SKPhysicsBody(circleOfRadius: Self.bodyRadius, center: CGPoint(x: 0, y: 4))
        physics.isDynamic = true
        physics.affectedByGravity = false
        physics.allowsRotation = false
        physics.categoryBitMask = PhysicsCategory.hero
        physics.contactTestBitMask = PhysicsCategory.boulder | PhysicsCategory.ember | PhysicsCategory.shard
        physics.collisionBitMask = PhysicsCategory.none
        physicsBody = physics

        startRunCycle()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("HeroNode does not support NSCoding")
    }

    // MARK: - Animation

    private func startRunCycle() {
        let cycle = SKAction.animate(with: runFrames, timePerFrame: 0.1, resize: false, restore: false)
        sprite.run(.repeatForever(cycle), withKey: "run")
        // Idle pace until the hero actually moves.
        sprite.speed = 0.45
        let pulse = SKAction.sequence([.fadeAlpha(to: 0.32, duration: 0.8), .fadeAlpha(to: 0.18, duration: 0.8)])
        aura.run(.repeatForever(pulse), withKey: "aura")
    }

    /// Leans and faces the hero in the direction of travel. `amount` is in `-1...1`.
    func setLean(_ amount: CGFloat) {
        let clamped = min(max(amount, -1), 1)
        sprite.zRotation = -clamped * 0.16
        if abs(clamped) > 0.15 {
            sprite.xScale = clamped < 0 ? -1 : 1
        }
        sprite.speed = 0.45 + abs(clamped) * 1.1
        trail.particleBirthRate = (isOverdriveVisible ? 140 : 30) + abs(clamped) * 50
    }

    private var isShieldShown: Bool?

    /// Shows or hides the shield bubble. Cheap to call every frame: only changes animate.
    func setShieldVisible(_ visible: Bool, animated: Bool = true) {
        guard visible != isShieldShown else { return }
        isShieldShown = visible
        let target: CGFloat = visible ? 0.95 : 0
        if animated {
            shieldBubble.run(.fadeAlpha(to: target, duration: 0.3), withKey: "shieldFade")
            if visible {
                shieldBubble.setScale(0.6)
                let grow = SKAction.scale(to: 1, duration: 0.35)
                grow.timingMode = .easeOut
                shieldBubble.run(grow)
                let spin = SKAction.rotate(byAngle: .pi * 2, duration: 8)
                shieldBubble.run(.repeatForever(spin), withKey: "spin")
            }
        } else {
            shieldBubble.alpha = target
        }
    }

    private var isOverdriveVisible = false

    /// Turns the hero molten while overdrive is active.
    func setOverdrive(_ active: Bool) {
        guard active != isOverdriveVisible else { return }
        isOverdriveVisible = active
        if active {
            sprite.color = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)
            sprite.run(.colorize(withColorBlendFactor: 0.55, duration: 0.15), withKey: "tint")
            aura.color = UIColor(red: 1.0, green: 0.6, blue: 0.15, alpha: 1)
            aura.removeAction(forKey: "aura")
            aura.size = CGSize(width: 130, height: 130)
            aura.alpha = 0.6
            trail.particleColor = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1)
            let pulse = SKAction.sequence([.scale(to: 1.1, duration: 0.18), .scale(to: 1.0, duration: 0.18)])
            run(.repeatForever(pulse), withKey: "overdrivePulse")
        } else {
            sprite.run(.colorize(withColorBlendFactor: 0, duration: 0.2), withKey: "tint")
            aura.color = glowColor
            aura.size = CGSize(width: 96, height: 96)
            aura.alpha = 0.22
            let pulse = SKAction.sequence([.fadeAlpha(to: 0.32, duration: 0.8), .fadeAlpha(to: 0.18, duration: 0.8)])
            aura.run(.repeatForever(pulse), withKey: "aura")
            trail.particleColor = glowColor
            removeAction(forKey: "overdrivePulse")
            run(.scale(to: 1.0, duration: 0.15))
        }
    }

    /// Expanding fire ring used when rage discharges as a shockwave.
    func playShockwave(radius: CGFloat) {
        let ring = SKSpriteNode(texture: TextureFactory.named(Art.shockwaveRing))
        ring.size = CGSize(width: 60, height: 60)
        ring.blendMode = .add
        ring.zPosition = 3
        addChild(ring)
        let scale = SKAction.scale(to: radius / 30, duration: 0.5)
        scale.timingMode = .easeOut
        ring.run(.sequence([.group([scale, .sequence([.wait(forDuration: 0.2), .fadeOut(withDuration: 0.3)])]), .removeFromParent()]))
    }

    /// Bursts the bubble when the shield absorbs a hit.
    func playShieldBreak() {
        let burst = SKSpriteNode(texture: TextureFactory.named(Art.shieldBubble))
        burst.size = shieldBubble.size
        burst.position = shieldBubble.position
        burst.zPosition = 2
        addChild(burst)
        burst.run(.sequence([
            .group([.scale(to: 2.0, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent()
        ]))
        shieldBubble.removeAction(forKey: "spin")
        setShieldVisible(false)
    }

    /// A short golden pulse when heart shards restore a heart.
    func playHeal() {
        let flash = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        flash.size = CGSize(width: 70, height: 70)
        flash.position = CGPoint(x: 0, y: 4)
        flash.color = UIColor(red: 1.0, green: 0.35, blue: 0.4, alpha: 1)
        flash.colorBlendFactor = 1
        flash.blendMode = .add
        flash.zPosition = 4
        addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 2.4, duration: 0.45), .fadeOut(withDuration: 0.45)]),
            .removeFromParent()
        ]))
    }

    /// Blinks while the hero is invulnerable after taking damage.
    func playDamageBlink(duration: TimeInterval) {
        guard !isOverdriveVisible else { return }
        removeAction(forKey: "blink")
        let blink = SKAction.sequence([.fadeAlpha(to: 0.3, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08)])
        let count = max(1, Int(duration / 0.16))
        run(.sequence([.repeat(blink, count: count), .fadeAlpha(to: 1, duration: 0.05)]), withKey: "blink")

        sprite.color = .white
        sprite.colorBlendFactor = 0.9
        sprite.run(.colorize(withColorBlendFactor: 0, duration: 0.18), withKey: "tint")
    }

    /// Plays the defeat animation and calls `completion` when done.
    func playDefeat(completion: @escaping @MainActor () -> Void) {
        physicsBody = nil
        trail.particleBirthRate = 0
        sprite.removeAction(forKey: "run")

        let burst = SKEmitterNode()
        burst.particleTexture = TextureFactory.softCircle(diameter: 32)
        burst.numParticlesToEmit = 40
        burst.particleBirthRate = 400
        burst.particleLifetime = 0.8
        burst.particleSpeed = 220
        burst.particleSpeedRange = 120
        burst.emissionAngleRange = .pi * 2
        burst.particleScale = 0.7
        burst.particleScaleSpeed = -0.8
        burst.particleAlphaSpeed = -1.2
        burst.particleColor = glowColor
        burst.particleColorBlendFactor = 1
        burst.particleBlendMode = .add
        burst.zPosition = 2
        addChild(burst)

        sprite.color = UIColor(red: 0.15, green: 0.1, blue: 0.12, alpha: 1)
        let collapse = SKAction.group([
            .colorize(withColorBlendFactor: 0.8, duration: 0.25),
            .scale(to: 0.1, duration: 0.5),
            .rotate(byAngle: .pi * 1.5, duration: 0.5),
            .fadeOut(withDuration: 0.5)
        ])
        collapse.timingMode = .easeIn
        sprite.run(collapse)
        shieldBubble.run(.fadeOut(withDuration: 0.2))
        aura.run(.fadeOut(withDuration: 0.3))
        shadow.run(.fadeOut(withDuration: 0.3))
        run(.sequence([.wait(forDuration: 0.8), .run { completion() }]))
    }
}
