import SpriteKit

/// A red crystal dropped by a smashed hot boulder. Three of them restore a heart.
@MainActor
final class HeartShardNode: SKNode {
    static let pickupRadius: CGFloat = 16
    /// Seconds before an uncollected shard crumbles.
    static let lifetime: TimeInterval = 6
    private(set) var isCollected = false

    override init() {
        super.init()
        zPosition = SceneLayer.embers + 1

        let glow = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        glow.size = CGSize(width: 64, height: 64)
        glow.color = UIColor(red: 1.0, green: 0.2, blue: 0.3, alpha: 1)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.7
        addChild(glow)

        let crystal = SKSpriteNode(texture: TextureFactory.named(Art.heartShard))
        crystal.size = CGSize(width: 38, height: 38)
        addChild(crystal)

        let pulse = SKAction.sequence([.scale(to: 1.3, duration: 0.35), .scale(to: 0.9, duration: 0.35)])
        glow.run(.repeatForever(pulse))
        crystal.run(.repeatForever(.sequence([.scaleX(to: -1, duration: 0.5), .scaleX(to: 1, duration: 0.5)])))

        // Blink before crumbling so the player knows to hurry.
        run(.sequence([
            .wait(forDuration: Self.lifetime - 1.5),
            .repeat(.sequence([.fadeAlpha(to: 0.3, duration: 0.15), .fadeAlpha(to: 1, duration: 0.15)]), count: 5),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]), withKey: "lifetime")

        let body = SKPhysicsBody(circleOfRadius: Self.pickupRadius)
        body.categoryBitMask = PhysicsCategory.shard
        body.contactTestBitMask = PhysicsCategory.hero
        body.collisionBitMask = PhysicsCategory.none
        body.affectedByGravity = true
        body.linearDamping = 1.4
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("HeartShardNode does not support NSCoding")
    }

    /// Stops the fall once the shard reaches the ground so it can be picked up.
    func settle(onGroundAt y: CGFloat) {
        guard let body = physicsBody, position.y <= y else { return }
        position.y = y
        body.affectedByGravity = false
        body.velocity = .zero
    }

    func collect() {
        guard !isCollected else { return }
        isCollected = true
        physicsBody = nil
        removeAction(forKey: "lifetime")
        run(.sequence([
            .group([.scale(to: 2, duration: 0.22), .fadeOut(withDuration: 0.22), .moveBy(x: 0, y: 24, duration: 0.22)]),
            .removeFromParent()
        ]))
    }
}
