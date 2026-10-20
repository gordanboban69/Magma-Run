import SpriteKit
import UIKit

/// Generates every texture the game needs at runtime, so the project ships
/// without bitmap assets. Results are cached per key.
@MainActor
enum TextureFactory {
    private static var cache: [String: SKTexture] = [:]

    /// A white circle fading to transparent, used for glows and particles.
    static func softCircle(diameter: CGFloat = 64) -> SKTexture {
        cached("soft-\(Int(diameter))") {
            render(size: CGSize(width: diameter, height: diameter)) { context, size in
                let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width / 2, options: [])
            }
        }
    }

    /// A vertical gradient filling `size`, from the first color at the top to the last at the bottom.
    static func verticalGradient(size: CGSize, colors: [UIColor], key: String) -> SKTexture {
        cached("gradient-\(key)-\(Int(size.width))x\(Int(size.height))") {
            render(size: size) { context, size in
                let cgColors = colors.map(\.cgColor) as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) else { return }
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
    }

    /// A procedurally drawn volcanic rock. `variant` selects the silhouette; `hot` adds glowing cracks.
    static func boulder(variant: Int, hot: Bool, diameter: CGFloat = 96) -> SKTexture {
        cached("boulder-\(variant)-\(hot)-\(Int(diameter))") {
            render(size: CGSize(width: diameter, height: diameter)) { context, size in
                var generator = SeededGenerator(seed: UInt64(variant + 1) &* 7_919)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerRadius = size.width * 0.46
                let pointCount = 11

                let path = CGMutablePath()
                for index in 0..<pointCount {
                    let angle = CGFloat(index) / CGFloat(pointCount) * .pi * 2
                    let radius = outerRadius * CGFloat.random(in: 0.78...1.0, using: &generator)
                    let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()

                context.saveGState()
                context.addPath(path)
                context.clip()
                let rockColors = [
                    UIColor(red: 0.46, green: 0.40, blue: 0.40, alpha: 1).cgColor,
                    UIColor(red: 0.26, green: 0.20, blue: 0.21, alpha: 1).cgColor,
                    UIColor(red: 0.12, green: 0.08, blue: 0.09, alpha: 1).cgColor
                ] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: rockColors, locations: [0, 0.55, 1]) {
                    let highlight = CGPoint(x: center.x - outerRadius * 0.3, y: center.y + outerRadius * 0.35)
                    context.drawRadialGradient(gradient, startCenter: highlight, startRadius: 0, endCenter: center, endRadius: outerRadius * 1.1, options: [.drawsAfterEndLocation])
                }

                // Small craters for texture.
                context.setFillColor(UIColor(white: 0, alpha: 0.28).cgColor)
                for _ in 0..<4 {
                    let craterRadius = CGFloat.random(in: 4...9, using: &generator)
                    let offset = CGPoint(
                        x: CGFloat.random(in: -outerRadius * 0.5...outerRadius * 0.5, using: &generator),
                        y: CGFloat.random(in: -outerRadius * 0.5...outerRadius * 0.5, using: &generator)
                    )
                    context.fillEllipse(in: CGRect(x: center.x + offset.x - craterRadius, y: center.y + offset.y - craterRadius, width: craterRadius * 2, height: craterRadius * 1.6))
                }

                if hot {
                    context.setStrokeColor(UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.95).cgColor)
                    context.setLineWidth(3)
                    context.setLineCap(.round)
                    for _ in 0..<5 {
                        let angle = CGFloat.random(in: 0...(.pi * 2), using: &generator)
                        let length = outerRadius * CGFloat.random(in: 0.45...0.95, using: &generator)
                        let bend = CGFloat.random(in: -0.6...0.6, using: &generator)
                        context.move(to: center)
                        let mid = CGPoint(x: center.x + cos(angle + bend) * length * 0.5, y: center.y + sin(angle + bend) * length * 0.5)
                        let end = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
                        context.addLine(to: mid)
                        context.addLine(to: end)
                        context.strokePath()
                    }
                }
                context.restoreGState()

                context.addPath(path)
                context.setStrokeColor(UIColor(white: 0, alpha: 0.6).cgColor)
                context.setLineWidth(2.5)
                context.strokePath()
            }
        }
    }

    // MARK: - Helpers

    private static func cached(_ key: String, make: () -> SKTexture) -> SKTexture {
        if let texture = cache[key] { return texture }
        let texture = make()
        cache[key] = texture
        return texture
    }

    private static func render(size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            draw(context.cgContext, size)
        }
        return SKTexture(image: image)
    }
}
