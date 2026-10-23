import SpriteKit

/// A rock launched by the volcano. Hot boulders glow and drop heart shards when smashed.
@MainActor
final class BoulderNode: SKSpriteNode {
    let radius: CGFloat
    let isHot: Bool
    /// Set once the boulder has passed below the hero so a dodge is only counted once.
    var hasBeenDodged = false

    init(radius: CGFloat, variant: Int, isHot: Bool) {
        self.radius = radius
        self.isHot = isHot
        let texture = TextureFactory.named(Art.boulder(variant: variant, hot: isHot))
        // The painted rock fills about 80% of its 120 pt canvas.
        let side = radius * 2.5
        super.init(texture: texture, color: .clear, size: CGSize(width: side, height: side))

        zPosition = SceneLayer.boulders

        if isHot {
            let glow = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
            glow.size = CGSize(width: radius * 4.2, height: radius * 4.2)
            glow.color = UIColor(red: 1.0, green: 0.45, blue: 0.1, alpha: 1)
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.alpha = 0.5
            glow.zPosition = -1
            addChild(glow)
            let pulse = SKAction.sequence([.fadeAlpha(to: 0.25, duration: 0.35), .fadeAlpha(to: 0.55, duration: 0.35)])
            glow.run(.repeatForever(pulse))
        }

        let body = SKPhysicsBody(circleOfRadius: radius * 0.82)
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

    /// Breaks the boulder into tumbling chips plus dust and removes it from the scene.
    func shatter() {
        physicsBody = nil
        guard let parent else { return }

        let chips = TextureFactory.frames(Art.rockChips)
        let chipCount = Int(radius / 6) + 3
        for index in 0..<chipCount {
            let chip = SKSpriteNode(texture: chips[index % chips.count])
            let side = CGFloat.random(in: 8...14) * (radius / 22)
            chip.size = CGSize(width: side, height: side)
            chip.position = position
            chip.zRotation = CGFloat.random(in: 0...(.pi * 2))
            chip.zPosition = SceneLayer.effects
            if isHot {
                chip.color = UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 1)
                chip.colorBlendFactor = 0.35
            }
            parent.addChild(chip)

            let angle = CGFloat(index) / CGFloat(chipCount) * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let distance = CGFloat.random(in: 40...90) * (radius / 22)
            let flight = SKAction.move(by: CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance - 30), duration: 0.5)
            flight.timingMode = .easeOut
            chip.run(.sequence([
                .group([flight, .rotate(byAngle: CGFloat.random(in: -6...6), duration: 0.5), .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.25)])]),
                .removeFromParent()
            ]))
        }

        let dust = SKEmitterNode()
        dust.particleTexture = TextureFactory.softCircle(diameter: 32)
        dust.numParticlesToEmit = 12
        dust.particleBirthRate = 300
        dust.particleLifetime = 0.6
        dust.particleSpeed = 90
        dust.particleSpeedRange = 50
        dust.emissionAngleRange = .pi * 2
        dust.particleScale = 0.7
        dust.particleScaleSpeed = 0.4
        dust.particleAlpha = 0.5
        dust.particleAlphaSpeed = -0.9
        dust.particleColor = isHot
            ? UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 1)
            : UIColor(red: 0.45, green: 0.38, blue: 0.38, alpha: 1)
        dust.particleColorBlendFactor = 1
        dust.particleBlendMode = isHot ? .add : .alpha
        dust.position = position
        dust.zPosition = SceneLayer.effects - 1
        parent.addChild(dust)
        dust.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))

        run(.sequence([
            .group([.scale(to: 0.3, duration: 0.1), .fadeOut(withDuration: 0.1)]),
            .removeFromParent()
        ]))
    }
}
