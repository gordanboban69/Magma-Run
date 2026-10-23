import SpriteKit

/// Visualises a `LavaRiver`: glowing cracks while warning, molten lava while flowing.
/// When the river drains it cools into an `ObsidianCrust` strip (see `CrustNode`).
@MainActor
final class LavaRiverNode: SKNode {
    private let cracks: SKNode
    private let lava: SKNode
    private var emitter: SKEmitterNode?
    private(set) var phase: LavaRiver.Phase = .warning
    private let width: CGFloat
    private let groundHeight: CGFloat

    init(width: CGFloat, groundHeight: CGFloat) {
        self.width = width
        self.groundHeight = groundHeight
        cracks = SceneryBuilder.makeTiledStrip(Art.crackWarning, width: width, height: groundHeight)
        lava = SceneryBuilder.makeTiledStrip(Art.lavaTile, width: width, height: groundHeight + 6)
        lava.alpha = 0

        super.init()
        zPosition = SceneLayer.ground + 1
        addChild(cracks)
        addChild(lava)

        let blink = SKAction.sequence([.fadeAlpha(to: 0.3, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)])
        cracks.run(.repeatForever(blink), withKey: "blink")
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("LavaRiverNode does not support NSCoding")
    }

    /// Switches from the warning look to flowing lava that rises out of the cracks.
    func startFlowing(width: CGFloat) {
        guard phase == .warning else { return }
        phase = .flowing
        cracks.removeAction(forKey: "blink")
        cracks.run(.fadeOut(withDuration: 0.3))

        lava.yScale = 0.2
        lava.run(.group([.fadeIn(withDuration: 0.25), .scaleY(to: 1, duration: 0.35)]))
        // A slow brightness pulse so the surface reads as liquid.
        let glow = SKAction.sequence([.fadeAlpha(to: 0.85, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])
        lava.run(.sequence([.wait(forDuration: 0.35), .repeatForever(glow)]))

        let bubbles = SKEmitterNode()
        bubbles.particleTexture = TextureFactory.softCircle(diameter: 32)
        bubbles.position = CGPoint(x: width / 2, y: groundHeight * 0.7)
        bubbles.particlePositionRange = CGVector(dx: width, dy: groundHeight * 0.4)
        bubbles.particleBirthRate = 50
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
        run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
    }
}

/// The glossy obsidian strip a drained river leaves behind. Standing on it doubles score.
@MainActor
final class CrustNode: SKNode {
    private let shine: SKSpriteNode

    init(width: CGFloat, groundHeight: CGFloat) {
        let slab = SceneryBuilder.makeTiledStrip(Art.crustTile, width: width, height: groundHeight)
        shine = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        super.init()
        zPosition = SceneLayer.ground + 1
        alpha = 0
        addChild(slab)

        // A highlight that sweeps across the glass while the bonus is up.
        shine.size = CGSize(width: 70, height: groundHeight * 0.9)
        shine.position = CGPoint(x: 0, y: groundHeight * 0.55)
        shine.color = UIColor(red: 1.0, green: 0.8, blue: 0.55, alpha: 1)
        shine.colorBlendFactor = 1
        shine.blendMode = .add
        shine.alpha = 0.25
        addChild(shine)
        let sweep = SKAction.sequence([
            .moveTo(x: width, duration: 1.4),
            .moveTo(x: 0, duration: 0)
        ])
        shine.run(.repeatForever(.sequence([sweep, .wait(forDuration: 0.6)])))

        // Molten seam along the top edge so the slab stands out from the basalt.
        let rim = SKSpriteNode(color: UIColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1), size: CGSize(width: width, height: 3))
        rim.anchorPoint = CGPoint(x: 0, y: 0.5)
        rim.position = CGPoint(x: 0, y: groundHeight)
        rim.blendMode = .add
        addChild(rim)
        rim.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))

        let marker = SKLabelNode(text: "×2")
        marker.fontName = "Futura-CondensedExtraBold"
        marker.fontSize = 26
        marker.fontColor = UIColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1)
        marker.position = CGPoint(x: width / 2, y: groundHeight + 58)
        marker.verticalAlignmentMode = .center
        addChild(marker)
        marker.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.6), .moveBy(x: 0, y: -6, duration: 0.6)])))
        self.marker = marker

        run(.fadeIn(withDuration: 0.5))
    }

    private var marker: SKLabelNode?

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("CrustNode does not support NSCoding")
    }

    /// Brightens the glow while the hero is standing on it.
    func setActive(_ active: Bool) {
        shine.alpha = active ? 0.55 : 0.25
        marker?.setScale(active ? 1.25 : 1)
    }

    /// Crumbles away when the crust expires.
    func crumble() {
        run(.sequence([.fadeOut(withDuration: 0.6), .removeFromParent()]))
    }
}
