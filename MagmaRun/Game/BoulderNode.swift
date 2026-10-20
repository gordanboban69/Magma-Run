import SpriteKit

/// A rock launched by the volcano. Hot boulders glow but behave identically.
@MainActor
final class BoulderNode: SKSpriteNode {
    let radius: CGFloat
    let isHot: Bool
    /// Set once the boulder has passed below the hero so a dodge is only counted once.
    var hasBeenDodged = false

    init(radius: CGFloat, variant: Int, isHot: Bool) {
        self.radius = radius
        self.isHot = isHot
        let texture = TextureFactory.boulder(variant: variant, hot: isHot)
        super.init(texture: texture, color: .clear, size: CGSize(width: radius * 2.15, height: radius * 2.15))

        zPosition = SceneLayer.boulders

        if isHot {
            let glow = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
            glow.size = CGSize(width: radius * 4.2, height: radius * 4.2)
            glow.color = UIColor(red: 1.0, green: 0.45, blue: 0.1, alpha: 1)
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.alpha = 0.55
            glow.zPosition = -1
            addChild(glow)
            let pulse = SKAction.sequence([.fadeAlpha(to: 0.3, duration: 0.35), .fadeAlpha(to: 0.6, duration: 0.35)])
            glow.run(.repeatForever(pulse))
        }

        let body = SKPhysicsBody(circleOfRadius: radius * 0.92)
        body.categoryBitMask = PhysicsCategory.boulder
        body.contactTestBitMask = PhysicsCategory.hero
        body.collisionBitMask = PhysicsCategory.none
        body.linearDamping = 0
        body.angularDamping = 0
        body.friction = 0
        body.mass = radius * 0.1
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BoulderNode does not support NSCoding")
    }

    /// Breaks the boulder into fragments and removes it from the scene.
    func shatter() {
        physicsBody = nil
        guard let parent else { return }

        let fragments = SKEmitterNode()
        fragments.particleTexture = TextureFactory.softCircle(diameter: 32)
        fragments.numParticlesToEmit = 18
        fragments.particleBirthRate = 300
        fragments.particleLifetime = 0.6
        fragments.particleSpeed = 160
        fragments.particleSpeedRange = 90
        fragments.emissionAngleRange = .pi * 2
        fragments.particleScale = 0.45
        fragments.particleScaleSpeed = -0.6
        fragments.particleAlphaSpeed = -1.5
        fragments.particleColor = isHot
            ? UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 1)
            : UIColor(red: 0.6, green: 0.52, blue: 0.5, alpha: 1)
        fragments.particleColorBlendFactor = 1
        fragments.particleBlendMode = isHot ? .add : .alpha
        fragments.position = position
        fragments.zPosition = SceneLayer.effects
        parent.addChild(fragments)
        fragments.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))

        run(.sequence([
            .group([.scale(to: 0.2, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .removeFromParent()
        ]))
    }
}
