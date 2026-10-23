import SpriteKit
import UIKit

/// Hands out every texture the scene uses: generated bitmaps from the asset catalog
/// plus a few tiny procedural particles. Results are cached per key.
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

    /// A generated bitmap from the asset catalog, cached so every node shares one texture.
    static func named(_ name: String) -> SKTexture {
        cached("asset-\(name)") {
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .linear
            return texture
        }
    }

    /// Several catalog bitmaps in order, e.g. animation frames.
    static func frames(_ names: [String]) -> [SKTexture] {
        names.map(named)
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
