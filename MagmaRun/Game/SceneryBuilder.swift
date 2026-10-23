import SpriteKit

/// Builds the backdrop from the generated art: mood skies, the volcano, crater effects,
/// ash and the ground strip. Rebuilt when the scene size changes.
@MainActor
enum SceneryBuilder {
    struct Layout {
        let craterPoint: CGPoint
        let heroY: CGFloat

        /// Top edge of the ground strip the hero runs along.
        var groundTop: CGFloat { heroY - HeroNode.bodyRadius - 10 }
    }

    /// Computes key positions for a given scene size.
    static func layout(for size: CGSize) -> Layout {
        // Low enough that the HUD score panel never hides boulders leaving the crater.
        let craterY = size.height * 0.75
        // Keep the hero above the home indicator and on-screen controls.
        let heroY = max(size.height * 0.16, 130)
        return Layout(craterPoint: CGPoint(x: size.width / 2, y: craterY), heroY: heroY)
    }

    /// A full-screen sky for the given mood, scaled to fill like `scaledToFill`.
    static func makeSky(for mood: VolcanoMood, size: CGSize) -> SKSpriteNode {
        let texture = TextureFactory.named(Art.sky(mood))
        let textureSize = texture.size()
        let scale = max(size.width / max(textureSize.width, 1), size.height / max(textureSize.height, 1))
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.zPosition = SceneLayer.background
        return node
    }

    static func makeCraterGlow(at point: CGPoint, sceneSize: CGSize) -> SKSpriteNode {
        let glow = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        let diameter = max(sceneSize.width, 420) * 1.1
        glow.size = CGSize(width: diameter, height: diameter * 0.75)
        glow.position = point
        glow.color = UIColor(red: 1.0, green: 0.40, blue: 0.10, alpha: 1)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.5
        glow.zPosition = SceneLayer.craterGlow
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.3, duration: 1.4),
            .fadeAlpha(to: 0.6, duration: 1.4)
        ])
        pulse.timingMode = .easeInEaseOut
        glow.run(.repeatForever(pulse))
        return glow
    }

    /// The painted volcano, anchored so its crater sits exactly on `crater`.
    static func makeMountain(size: CGSize, crater: CGPoint) -> SKSpriteNode {
        let texture = TextureFactory.named(Art.volcano)
        let art = Art.volcanoSize
        // Wide enough for the screen and tall enough to reach the bottom edge.
        let scale = max(size.width / art.width, crater.y / (art.height - Art.volcanoCrater.y))
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: art.width * scale, height: art.height * scale)
        node.anchorPoint = CGPoint(x: Art.volcanoCrater.x / art.width, y: 1 - Art.volcanoCrater.y / art.height)
        node.position = crater
        node.zPosition = SceneLayer.mountain
        return node
    }

    /// Animated lava splash above the crater. Call `run(burstAction)` to play it.
    static func makeCraterBurst(at point: CGPoint) -> SKSpriteNode {
        let frames = TextureFactory.frames(Art.craterBurstFrames)
        let node = SKSpriteNode(texture: frames.first)
        node.size = CGSize(width: 120, height: 90)
        node.anchorPoint = CGPoint(x: 0.5, y: 0.08)
        node.position = point
        node.zPosition = SceneLayer.mountain + 3
        node.alpha = 0
        return node
    }

    static var burstAction: SKAction {
        let frames = TextureFactory.frames(Art.craterBurstFrames)
        return .sequence([
            .fadeIn(withDuration: 0.04),
            .animate(with: frames, timePerFrame: 0.09, resize: false, restore: false),
            .fadeOut(withDuration: 0.12)
        ])
    }

    static func makeCraterSmoke(at point: CGPoint) -> SKEmitterNode {
        let smoke = SKEmitterNode()
        smoke.particleTexture = TextureFactory.softCircle(diameter: 64)
        smoke.position = CGPoint(x: point.x, y: point.y + 6)
        smoke.particleBirthRate = 12
        smoke.particleLifetime = 3.2
        smoke.particleLifetimeRange = 1
        smoke.particlePositionRange = CGVector(dx: 30, dy: 4)
        smoke.particleSpeed = 55
        smoke.particleSpeedRange = 20
        smoke.emissionAngle = .pi / 2
        smoke.emissionAngleRange = 0.5
        smoke.particleScale = 0.9
        smoke.particleScaleRange = 0.4
        smoke.particleScaleSpeed = 0.7
        smoke.particleAlpha = 0.4
        smoke.particleAlphaSpeed = -0.13
        smoke.particleColor = UIColor(red: 0.42, green: 0.3, blue: 0.32, alpha: 1)
        smoke.particleColorBlendFactor = 1
        smoke.zPosition = SceneLayer.mountain + 1
        return smoke
    }

    static func makeSparks(at point: CGPoint) -> SKEmitterNode {
        let sparks = SKEmitterNode()
        sparks.particleTexture = TextureFactory.softCircle(diameter: 32)
        sparks.position = point
        sparks.particleBirthRate = 22
        sparks.particleLifetime = 1.6
        sparks.particleLifetimeRange = 0.6
        sparks.particlePositionRange = CGVector(dx: 24, dy: 4)
        sparks.particleSpeed = 180
        sparks.particleSpeedRange = 80
        sparks.emissionAngle = .pi / 2
        sparks.emissionAngleRange = 0.9
        sparks.yAcceleration = -220
        sparks.particleScale = 0.28
        sparks.particleScaleSpeed = -0.15
        sparks.particleAlphaSpeed = -0.6
        sparks.particleColor = UIColor(red: 1.0, green: 0.7, blue: 0.25, alpha: 1)
        sparks.particleColorBlendFactor = 1
        sparks.particleBlendMode = .add
        sparks.zPosition = SceneLayer.mountain + 2
        return sparks
    }

    static func makeAsh(size: CGSize) -> SKEmitterNode {
        let ash = SKEmitterNode()
        ash.particleTexture = TextureFactory.softCircle(diameter: 32)
        ash.position = CGPoint(x: size.width / 2, y: size.height + 20)
        ash.particlePositionRange = CGVector(dx: size.width * 1.2, dy: 0)
        ash.particleBirthRate = 10
        ash.particleLifetime = 14
        ash.particleSpeed = 40
        ash.particleSpeedRange = 20
        ash.emissionAngle = -.pi / 2
        ash.emissionAngleRange = 0.3
        ash.particleScale = 0.14
        ash.particleScaleRange = 0.08
        ash.particleAlpha = 0.45
        ash.particleAlphaRange = 0.2
        ash.particleColor = UIColor(red: 0.7, green: 0.65, blue: 0.68, alpha: 1)
        ash.particleColorBlendFactor = 1
        ash.zPosition = SceneLayer.ash
        ash.advanceSimulationTime(12)
        return ash
    }

    /// The basalt strip the hero runs along, tiled from `ground_tile`.
    static func makeGround(size: CGSize, groundTop: CGFloat) -> SKNode {
        let container = SKNode()
        container.zPosition = SceneLayer.ground
        // The tile's glowing fissure sits 8 pt below its top edge.
        let strip = makeTiledStrip(Art.groundTile, width: size.width + 40, height: groundTop + 8)
        strip.position = CGPoint(x: -20, y: 0)
        container.addChild(strip)
        return container
    }

    /// Repeats a horizontally tileable 200 × 120 bitmap to fill `width` × `height`,
    /// with the origin at the bottom-left. Tiles keep their painted aspect ratio;
    /// the last one is cropped so narrow strips are never squashed.
    static func makeTiledStrip(_ name: String, width: CGFloat, height: CGFloat) -> SKNode {
        let tiles = SKNode()
        guard width > 0, height > 0 else { return tiles }
        let texture = TextureFactory.named(name)
        let tileWidth = height * (200.0 / 120.0)
        let count = max(1, Int((width / tileWidth).rounded(.up)))
        for index in 0..<count {
            let tile = SKSpriteNode(texture: texture)
            tile.anchorPoint = .zero
            // Half a point of overlap hides hairline seams between tiles.
            tile.size = CGSize(width: tileWidth + 0.5, height: height)
            tile.position = CGPoint(x: CGFloat(index) * tileWidth, y: 0)
            tiles.addChild(tile)
        }

        let crop = SKCropNode()
        let mask = SKSpriteNode(color: .white, size: CGSize(width: width, height: height))
        mask.anchorPoint = .zero
        crop.maskNode = mask
        crop.addChild(tiles)
        return crop
    }
}
