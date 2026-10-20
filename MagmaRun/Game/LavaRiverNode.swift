import SpriteKit

/// Visualises a `LavaRiver`: cracked glowing ground while warning, molten lava while flowing.
@MainActor
final class LavaRiverNode: SKNode {
    private let fill: SKShapeNode
    private let cracks: SKShapeNode
    private var emitter: SKEmitterNode?
    private(set) var phase: LavaRiver.Phase = .warning
    private let groundHeight: CGFloat

    init(width: CGFloat, groundHeight: CGFloat) {
        self.groundHeight = groundHeight
        let rect = CGRect(x: 0, y: -40, width: width, height: groundHeight + 40)
        fill = SKShapeNode(rect: rect)
        fill.fillColor = UIColor(red: 1.0, green: 0.42, blue: 0.1, alpha: 1)
        fill.strokeColor = UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1)
        fill.lineWidth = 2
        fill.glowWidth = 10
        fill.alpha = 0

        let path = CGMutablePath()
        var x: CGFloat = 8
        while x < width - 8 {
            let length = CGFloat.random(in: 18...40)
            path.move(to: CGPoint(x: x, y: CGFloat.random(in: 4...(groundHeight - 6))))
            path.addLine(to: CGPoint(x: x + length * 0.5, y: CGFloat.random(in: 4...(groundHeight - 6))))
            path.addLine(to: CGPoint(x: x + length, y: CGFloat.random(in: 4...(groundHeight - 6))))
            x += length + CGFloat.random(in: 10...24)
        }
        cracks = SKShapeNode(path: path)
        cracks.strokeColor = UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 1)
        cracks.lineWidth = 2.5
        cracks.glowWidth = 6
        cracks.lineCap = .round

        super.init()
        zPosition = SceneLayer.ground + 1
        addChild(fill)
        addChild(cracks)

        let blink = SKAction.sequence([.fadeAlpha(to: 0.35, duration: 0.22), .fadeAlpha(to: 1, duration: 0.22)])
        cracks.run(.repeatForever(blink), withKey: "blink")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("LavaRiverNode does not support NSCoding")
    }

    /// Switches from the warning look to flowing lava.
    func startFlowing(width: CGFloat) {
        guard phase == .warning else { return }
        phase = .flowing
        cracks.removeAction(forKey: "blink")
        cracks.run(.fadeOut(withDuration: 0.3))
        fill.run(.fadeAlpha(to: 0.92, duration: 0.35))

        let bubbles = SKEmitterNode()
        bubbles.particleTexture = TextureFactory.softCircle(diameter: 32)
        bubbles.position = CGPoint(x: width / 2, y: groundHeight * 0.6)
        bubbles.particlePositionRange = CGVector(dx: width, dy: groundHeight * 0.6)
        bubbles.particleBirthRate = 60
        bubbles.particleLifetime = 0.9
        bubbles.particleSpeed = 70
        bubbles.particleSpeedRange = 30
        bubbles.emissionAngle = .pi / 2
        bubbles.emissionAngleRange = 0.6
        bubbles.particleScale = 0.3
        bubbles.particleScaleSpeed = -0.3
        bubbles.particleAlphaSpeed = -1.1
        bubbles.particleColor = UIColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 1)
        bubbles.particleColorBlendFactor = 1
        bubbles.particleBlendMode = .add
        addChild(bubbles)
        emitter = bubbles
    }

    /// Fades the river out and removes it.
    func drain() {
        emitter?.particleBirthRate = 0
        run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
    }
}
