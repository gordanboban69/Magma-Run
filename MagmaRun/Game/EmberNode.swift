import SpriteKit

/// A glowing ember: the in-game currency that drifts down from the eruption.
@MainActor
final class EmberNode: SKNode {
    static let pickupRadius: CGFloat = 13
    /// Prevents double-collection when two contacts fire in the same frame.
    private(set) var isCollected = false

    override init() {
        super.init()
        zPosition = SceneLayer.embers

        let glow = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        glow.size = CGSize(width: 48, height: 48)
        glow.color = UIColor(red: 1.0, green: 0.62, blue: 0.15, alpha: 1)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.8
        addChild(glow)

        let core = SKShapeNode(circleOfRadius: 7)
        core.fillColor = UIColor(red: 1.0, green: 0.9, blue: 0.55, alpha: 1)
        core.strokeColor = UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1)
        core.lineWidth = 2
        core.glowWidth = 3
        addChild(core)

        let pulse = SKAction.sequence([
            .scale(to: 1.25, duration: 0.45),
            .scale(to: 0.9, duration: 0.45)
        ])
        pulse.timingMode = .easeInEaseOut
        glow.run(.repeatForever(pulse))

        let body = SKPhysicsBody(circleOfRadius: Self.pickupRadius)
        body.categoryBitMask = PhysicsCategory.ember
        body.contactTestBitMask = PhysicsCategory.hero
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = false
        body.linearDamping = 0
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("EmberNode does not support NSCoding")
    }

    /// Plays the pickup animation and removes the node.
    func collect() {
        guard !isCollected else { return }
        isCollected = true
        physicsBody = nil
        run(.sequence([
            .group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }
}
