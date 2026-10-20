import SpriteKit

/// Builds the static backdrop: sky, mountain, crater glow, ash and the ground fissure.
/// Everything is drawn procedurally and rebuilt when the scene size changes.
@MainActor
enum SceneryBuilder {
    struct Layout {
        let craterPoint: CGPoint
        let heroY: CGFloat
    }

    /// Computes key positions for a given scene size.
    static func layout(for size: CGSize) -> Layout {
        let craterY = size.height * 0.82
        // Keep the hero above the home indicator and on-screen controls.
        let heroY = max(size.height * 0.16, 130)
        return Layout(craterPoint: CGPoint(x: size.width / 2, y: craterY), heroY: heroY)
    }

    static func makeBackground(size: CGSize) -> SKSpriteNode {
        let texture = TextureFactory.verticalGradient(
            size: CGSize(width: 8, height: 256),
            colors: [
                UIColor(red: 0.04, green: 0.02, blue: 0.06, alpha: 1),
                UIColor(red: 0.12, green: 0.04, blue: 0.08, alpha: 1),
                UIColor(red: 0.30, green: 0.09, blue: 0.10, alpha: 1)
            ],
            key: "sky"
        )
        let node = SKSpriteNode(texture: texture, size: size)
        node.anchorPoint = .zero
        node.position = .zero
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
        glow.alpha = 0.55
        glow.zPosition = SceneLayer.craterGlow
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.35, duration: 1.4),
            .fadeAlpha(to: 0.65, duration: 1.4)
        ])
        pulse.timingMode = .easeInEaseOut
        glow.run(.repeatForever(pulse))
        return glow
    }

    /// The volcano silhouette: the hero stands at its foot, so the slope fills the screen below the crater.
    static func makeMountain(size: CGSize, crater: CGPoint) -> SKNode {
        let container = SKNode()
        container.zPosition = SceneLayer.mountain

        let topHalfWidth = max(size.width * 0.12, 46)
        let baseHalfWidth = size.width * 0.95
        let baseY: CGFloat = -40

        let path = CGMutablePath()
        path.move(to: CGPoint(x: crater.x - baseHalfWidth, y: baseY))
        // Left slope with jagged shoulders.
        path.addLine(to: CGPoint(x: crater.x - baseHalfWidth * 0.78, y: crater.y * 0.28))
        path.addLine(to: CGPoint(x: crater.x - baseHalfWidth * 0.62, y: crater.y * 0.42))
        path.addLine(to: CGPoint(x: crater.x - baseHalfWidth * 0.5, y: crater.y * 0.52))
        path.addLine(to: CGPoint(x: crater.x - baseHalfWidth * 0.3, y: crater.y * 0.74))
        path.addLine(to: CGPoint(x: crater.x - topHalfWidth * 1.4, y: crater.y * 0.93))
        path.addLine(to: CGPoint(x: crater.x - topHalfWidth, y: crater.y))
        // Crater dip.
        path.addLine(to: CGPoint(x: crater.x - topHalfWidth * 0.5, y: crater.y - 10))
        path.addLine(to: CGPoint(x: crater.x + topHalfWidth * 0.5, y: crater.y - 10))
        path.addLine(to: CGPoint(x: crater.x + topHalfWidth, y: crater.y))
        // Right slope.
        path.addLine(to: CGPoint(x: crater.x + topHalfWidth * 1.5, y: crater.y * 0.9))
        path.addLine(to: CGPoint(x: crater.x + baseHalfWidth * 0.34, y: crater.y * 0.7))
        path.addLine(to: CGPoint(x: crater.x + baseHalfWidth * 0.48, y: crater.y * 0.56))
        path.addLine(to: CGPoint(x: crater.x + baseHalfWidth * 0.66, y: crater.y * 0.4))
        path.addLine(to: CGPoint(x: crater.x + baseHalfWidth * 0.8, y: crater.y * 0.26))
        path.addLine(to: CGPoint(x: crater.x + baseHalfWidth, y: baseY))
        path.closeSubpath()

        let mountain = SKShapeNode(path: path)
        mountain.fillColor = UIColor(red: 0.11, green: 0.06, blue: 0.09, alpha: 1)
        mountain.strokeColor = UIColor(red: 0.35, green: 0.14, blue: 0.12, alpha: 0.9)
        mountain.lineWidth = 2
        container.addChild(mountain)

        // Lava streams running down from the crater.
        let streamColor = UIColor(red: 1.0, green: 0.42, blue: 0.12, alpha: 1)
        let streams: [[CGPoint]] = [
            [CGPoint(x: crater.x - topHalfWidth * 0.6, y: crater.y - 8),
             CGPoint(x: crater.x - topHalfWidth * 1.6, y: crater.y * 0.84),
             CGPoint(x: crater.x - topHalfWidth * 1.3, y: crater.y * 0.72),
             CGPoint(x: crater.x - baseHalfWidth * 0.3, y: crater.y * 0.5)],
            [CGPoint(x: crater.x + topHalfWidth * 0.4, y: crater.y - 8),
             CGPoint(x: crater.x + topHalfWidth * 1.1, y: crater.y * 0.8),
             CGPoint(x: crater.x + topHalfWidth * 2.0, y: crater.y * 0.62),
             CGPoint(x: crater.x + baseHalfWidth * 0.36, y: crater.y * 0.46)],
            [CGPoint(x: crater.x, y: crater.y - 10),
             CGPoint(x: crater.x + topHalfWidth * 0.3, y: crater.y * 0.78),
             CGPoint(x: crater.x - topHalfWidth * 0.2, y: crater.y * 0.6)]
        ]
        for (index, points) in streams.enumerated() {
            let streamPath = CGMutablePath()
            streamPath.addLines(between: points)
            let stream = SKShapeNode(path: streamPath)
            stream.strokeColor = streamColor
            stream.lineWidth = index == 2 ? 3 : 4
            stream.lineCap = .round
            stream.lineJoin = .round
            stream.glowWidth = 6
            stream.alpha = 0.85
            let flicker = SKAction.sequence([
                .fadeAlpha(to: 0.55, duration: Double.random(in: 0.6...1.1)),
                .fadeAlpha(to: 0.95, duration: Double.random(in: 0.6...1.1))
            ])
            stream.run(.repeatForever(flicker))
            container.addChild(stream)
        }

        // Molten crater rim.
        let rim = SKShapeNode(ellipseOf: CGSize(width: topHalfWidth * 2.1, height: 16))
        rim.position = CGPoint(x: crater.x, y: crater.y - 4)
        rim.fillColor = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1)
        rim.strokeColor = UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1)
        rim.lineWidth = 2
        rim.glowWidth = 10
        container.addChild(rim)

        return container
    }

    static func makeCraterSmoke(at point: CGPoint) -> SKEmitterNode {
        let smoke = SKEmitterNode()
        smoke.particleTexture = TextureFactory.softCircle(diameter: 64)
        smoke.position = CGPoint(x: point.x, y: point.y + 6)
        smoke.particleBirthRate = 14
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
        smoke.particleAlpha = 0.45
        smoke.particleAlphaSpeed = -0.15
        smoke.particleColor = UIColor(red: 0.45, green: 0.3, blue: 0.3, alpha: 1)
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

    /// A glowing fissure marking the ground the hero runs along.
    static func makeGround(size: CGSize, heroY: CGFloat) -> SKNode {
        let container = SKNode()
        container.zPosition = SceneLayer.ground

        let groundY = heroY - HeroNode.bodyRadius - 10
        let ground = SKShapeNode(rect: CGRect(x: -20, y: -60, width: size.width + 40, height: groundY + 60))
        ground.fillColor = UIColor(red: 0.07, green: 0.04, blue: 0.06, alpha: 1)
        ground.strokeColor = .clear
        container.addChild(ground)

        let fissure = CGMutablePath()
        fissure.move(to: CGPoint(x: -10, y: groundY))
        var x: CGFloat = 0
        var up = true
        while x < size.width + 20 {
            x += CGFloat.random(in: 18...42)
            let y = groundY + (up ? CGFloat.random(in: 2...6) : -CGFloat.random(in: 2...6))
            fissure.addLine(to: CGPoint(x: x, y: y))
            up.toggle()
        }
        let crack = SKShapeNode(path: fissure)
        crack.strokeColor = UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 1)
        crack.lineWidth = 2.5
        crack.glowWidth = 7
        crack.lineJoin = .round
        let flicker = SKAction.sequence([.fadeAlpha(to: 0.6, duration: 0.9), .fadeAlpha(to: 1, duration: 0.9)])
        crack.run(.repeatForever(flicker))
        container.addChild(crack)

        return container
    }
}
