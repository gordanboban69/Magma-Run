import SpriteKit

/// The player's character, assembled from vector shapes tinted with the selected skin.
@MainActor
final class HeroNode: SKNode {
    static let bodyRadius: CGFloat = 22

    private let body: SKShapeNode
    private let head: SKShapeNode
    private let visor: SKShapeNode
    private let emblem: SKShapeNode
    private let shieldRing: SKShapeNode
    private let trail: SKEmitterNode
    private let glowColor: UIColor
    private let primaryColor: UIColor

    init(skin: HeroSkin) {
        let primary = skin.primary.uiColor
        let secondary = skin.secondary.uiColor
        glowColor = skin.glow.uiColor
        primaryColor = primary

        body = SKShapeNode(path: CGPath(roundedRect: CGRect(x: -16, y: -24, width: 32, height: 40), cornerWidth: 15, cornerHeight: 15, transform: nil))
        body.fillColor = primary
        body.strokeColor = secondary
        body.lineWidth = 2.5

        head = SKShapeNode(circleOfRadius: 13)
        head.position = CGPoint(x: 0, y: 22)
        head.fillColor = primary
        head.strokeColor = secondary
        head.lineWidth = 2.5

        visor = SKShapeNode(path: CGPath(roundedRect: CGRect(x: -9, y: -4, width: 18, height: 8), cornerWidth: 4, cornerHeight: 4, transform: nil))
        visor.position = CGPoint(x: 0, y: 23)
        visor.fillColor = glowColor
        visor.strokeColor = .clear
        visor.glowWidth = 2

        let diamond = CGMutablePath()
        diamond.move(to: CGPoint(x: 0, y: 6))
        diamond.addLine(to: CGPoint(x: 5, y: 0))
        diamond.addLine(to: CGPoint(x: 0, y: -6))
        diamond.addLine(to: CGPoint(x: -5, y: 0))
        diamond.closeSubpath()
        emblem = SKShapeNode(path: diamond)
        emblem.position = CGPoint(x: 0, y: -4)
        emblem.fillColor = glowColor
        emblem.strokeColor = .clear
        emblem.glowWidth = 1.5

        shieldRing = SKShapeNode(circleOfRadius: 34)
        shieldRing.strokeColor = glowColor
        shieldRing.lineWidth = 3
        shieldRing.glowWidth = 8
        shieldRing.fillColor = glowColor.withAlphaComponent(0.08)
        shieldRing.alpha = 0

        trail = SKEmitterNode()
        trail.particleTexture = TextureFactory.softCircle(diameter: 32)
        trail.particleBirthRate = 45
        trail.particleLifetime = 0.55
        trail.particleLifetimeRange = 0.2
        trail.particlePositionRange = CGVector(dx: 14, dy: 2)
        trail.particleSpeed = 70
        trail.particleSpeedRange = 25
        trail.emissionAngle = -.pi / 2
        trail.emissionAngleRange = 0.5
        trail.particleScale = 0.55
        trail.particleScaleSpeed = -0.9
        trail.particleAlpha = 0.9
        trail.particleAlphaSpeed = -1.6
        trail.particleColor = glowColor
        trail.particleColorBlendFactor = 1
        trail.particleBlendMode = .add
        trail.position = CGPoint(x: 0, y: -24)
        trail.zPosition = -1

        super.init()

        addChild(trail)
        addChild(body)
        addChild(head)
        addChild(visor)
        addChild(emblem)
        addChild(shieldRing)

        let physics = SKPhysicsBody(circleOfRadius: Self.bodyRadius, center: CGPoint(x: 0, y: 4))
        physics.isDynamic = true
        physics.affectedByGravity = false
        physics.allowsRotation = false
        physics.categoryBitMask = PhysicsCategory.hero
        physics.contactTestBitMask = PhysicsCategory.boulder | PhysicsCategory.ember
        physics.collisionBitMask = PhysicsCategory.none
        physicsBody = physics

        runIdleBob()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("HeroNode does not support NSCoding")
    }

    // MARK: - Animation

    private func runIdleBob() {
        let up = SKAction.moveBy(x: 0, y: 3, duration: 0.9)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        head.run(.repeatForever(.sequence([up, down])), withKey: "idle")
    }

    /// Leans the body in the direction of travel. `amount` is in `-1...1`.
    func setLean(_ amount: CGFloat) {
        let clamped = min(max(amount, -1), 1)
        zRotation = -clamped * 0.22
        trail.particleBirthRate = 45 + abs(clamped) * 60
    }

    func setShieldVisible(_ visible: Bool, animated: Bool = true) {
        let target: CGFloat = visible ? 1 : 0
        if animated {
            shieldRing.run(.fadeAlpha(to: target, duration: 0.3), withKey: "shieldFade")
            if visible {
                shieldRing.setScale(0.6)
                shieldRing.run(.scale(to: 1, duration: 0.35))
            }
        } else {
            shieldRing.alpha = target
        }
    }

    /// Flashes the ring outward when the shield absorbs a hit.
    func playShieldBreak() {
        let burst = SKShapeNode(circleOfRadius: 34)
        burst.strokeColor = glowColor
        burst.lineWidth = 4
        burst.glowWidth = 10
        burst.zPosition = 1
        addChild(burst)
        burst.run(.sequence([
            .group([.scale(to: 2.2, duration: 0.35), .fadeOut(withDuration: 0.35)]),
            .removeFromParent()
        ]))
        setShieldVisible(false)
    }

    /// Blinks while the hero is invulnerable after taking damage.
    func playDamageBlink(duration: TimeInterval) {
        removeAction(forKey: "blink")
        let blink = SKAction.sequence([.fadeAlpha(to: 0.25, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08)])
        let count = max(1, Int(duration / 0.16))
        run(.sequence([.repeat(blink, count: count), .fadeAlpha(to: 1, duration: 0.05)]), withKey: "blink")

        let flash = SKAction.sequence([
            .run { [body, head] in
                body.fillColor = .white
                head.fillColor = .white
            },
            .wait(forDuration: 0.08),
            .run { [body, head, primaryColor] in
                body.fillColor = primaryColor
                head.fillColor = primaryColor
            }
        ])
        run(flash)
    }

    /// Plays the defeat animation and calls `completion` when done.
    func playDefeat(completion: @escaping @MainActor () -> Void) {
        physicsBody = nil
        trail.particleBirthRate = 0

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

        let collapse = SKAction.group([
            .scale(to: 0.1, duration: 0.5),
            .rotate(byAngle: .pi * 1.5, duration: 0.5),
            .fadeOut(withDuration: 0.5)
        ])
        collapse.timingMode = .easeIn
        run(.sequence([collapse, .wait(forDuration: 0.3), .run { completion() }]))
    }
}
