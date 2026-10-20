import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Procedural app icons for Magma Run and Sky Stack.
// Usage: swift gen.swift <output-directory>

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, a])!
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
}

func makeContext(_ size: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    return ctx
}

func save(_ ctx: CGContext, to url: URL) {
    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.path)")
}

// Seeded random so both sizes render identically.
struct Rng {
    var state: UInt64
    mutating func next() -> Double {
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        return Double((state &* 2685821657736338717) >> 11) / Double(1 << 53)
    }
    mutating func range(_ r: ClosedRange<Double>) -> Double { r.lowerBound + (r.upperBound - r.lowerBound) * next() }
}

// MARK: - Magma Run

func drawMagmaRun(size: Int) -> CGContext {
    let ctx = makeContext(size)
    let s = CGFloat(size)
    let u = s / 1024 // unit scale
    var rng = Rng(state: 0x5EED_1234)

    // Background: deep obsidian with warm glow at the bottom.
    ctx.drawLinearGradient(gradient([rgb(0.10, 0.04, 0.10), rgb(0.05, 0.02, 0.06), rgb(0.22, 0.05, 0.07)], [0, 0.55, 1]),
                           start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // Crater glow (radial, additive-looking).
    let crater = CGPoint(x: s * 0.5, y: s * 0.70)
    ctx.saveGState()
    ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([rgb(1.0, 0.45, 0.10, 0.95), rgb(1.0, 0.25, 0.05, 0.35), rgb(1.0, 0.2, 0.05, 0)], [0, 0.45, 1]),
                           startCenter: crater, startRadius: 0, endCenter: crater, endRadius: s * 0.42, options: [])
    ctx.restoreGState()

    // Mountain silhouette.
    let mountain = CGMutablePath()
    mountain.move(to: CGPoint(x: -s * 0.1, y: 0))
    mountain.addLine(to: CGPoint(x: s * 0.12, y: s * 0.26))
    mountain.addLine(to: CGPoint(x: s * 0.22, y: s * 0.36))
    mountain.addLine(to: CGPoint(x: s * 0.33, y: s * 0.52))
    mountain.addLine(to: CGPoint(x: s * 0.41, y: s * 0.68))
    mountain.addLine(to: CGPoint(x: s * 0.44, y: s * 0.70))
    mountain.addLine(to: CGPoint(x: s * 0.56, y: s * 0.70))
    mountain.addLine(to: CGPoint(x: s * 0.60, y: s * 0.66))
    mountain.addLine(to: CGPoint(x: s * 0.69, y: s * 0.50))
    mountain.addLine(to: CGPoint(x: s * 0.80, y: s * 0.34))
    mountain.addLine(to: CGPoint(x: s * 0.90, y: s * 0.22))
    mountain.addLine(to: CGPoint(x: s * 1.1, y: 0))
    mountain.closeSubpath()
    ctx.saveGState()
    ctx.addPath(mountain)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0.20, 0.10, 0.13), rgb(0.08, 0.04, 0.06)]),
                           start: CGPoint(x: 0, y: s * 0.7), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()
    ctx.addPath(mountain)
    ctx.setStrokeColor(rgb(0.45, 0.18, 0.14, 0.9))
    ctx.setLineWidth(6 * u)
    ctx.strokePath()

    // Lava streams.
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let streams: [[CGPoint]] = [
        [CGPoint(x: 0.47, y: 0.69), CGPoint(x: 0.43, y: 0.58), CGPoint(x: 0.45, y: 0.46), CGPoint(x: 0.38, y: 0.30), CGPoint(x: 0.40, y: 0.16)],
        [CGPoint(x: 0.54, y: 0.69), CGPoint(x: 0.58, y: 0.56), CGPoint(x: 0.56, y: 0.44), CGPoint(x: 0.63, y: 0.30), CGPoint(x: 0.61, y: 0.12)],
        [CGPoint(x: 0.50, y: 0.69), CGPoint(x: 0.51, y: 0.60), CGPoint(x: 0.49, y: 0.50)]
    ]
    for (i, pts) in streams.enumerated() {
        let path = CGMutablePath()
        path.addLines(between: pts.map { CGPoint(x: $0.x * s, y: $0.y * s) })
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 28 * u, color: rgb(1.0, 0.45, 0.1, 0.9))
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(1.0, 0.40, 0.10))
        ctx.setLineWidth((i == 2 ? 10 : 16) * u)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(1.0, 0.82, 0.40))
        ctx.setLineWidth((i == 2 ? 4 : 6) * u)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Crater rim.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 40 * u, color: rgb(1.0, 0.5, 0.15, 1))
    ctx.setFillColor(rgb(1.0, 0.55, 0.15))
    ctx.fillEllipse(in: CGRect(x: s * 0.43, y: s * 0.685, width: s * 0.14, height: s * 0.035))
    ctx.setFillColor(rgb(1.0, 0.85, 0.45))
    ctx.fillEllipse(in: CGRect(x: s * 0.455, y: s * 0.692, width: s * 0.09, height: s * 0.02))
    ctx.restoreGState()

    // Flying boulders with hot cracks.
    func boulder(center: CGPoint, radius: CGFloat, hot: Bool, seed: inout Rng) {
        let path = CGMutablePath()
        let n = 10
        for k in 0..<n {
            let a = CGFloat(k) / CGFloat(n) * .pi * 2
            let r = radius * CGFloat(seed.range(0.78...1.0))
            let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            k == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6 * u), blur: 18 * u, color: rgb(0, 0, 0, 0.6))
        ctx.addPath(path)
        ctx.setFillColor(rgb(0.30, 0.24, 0.25))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawRadialGradient(gradient([rgb(0.50, 0.44, 0.44), rgb(0.26, 0.20, 0.21), rgb(0.10, 0.07, 0.08)], [0, 0.6, 1]),
                               startCenter: CGPoint(x: center.x - radius * 0.3, y: center.y + radius * 0.35), startRadius: 0,
                               endCenter: center, endRadius: radius * 1.15, options: [.drawsAfterEndLocation])
        if hot {
            ctx.setStrokeColor(rgb(1.0, 0.55, 0.15, 0.95))
            ctx.setLineWidth(5 * u)
            for _ in 0..<5 {
                let a = CGFloat(seed.range(0...(2 * .pi)))
                let len = radius * CGFloat(seed.range(0.5...0.95))
                ctx.move(to: center)
                ctx.addLine(to: CGPoint(x: center.x + cos(a + 0.4) * len * 0.5, y: center.y + sin(a + 0.4) * len * 0.5))
                ctx.addLine(to: CGPoint(x: center.x + cos(a) * len, y: center.y + sin(a) * len))
                ctx.strokePath()
            }
        }
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(0, 0, 0, 0.55))
        ctx.setLineWidth(4 * u)
        ctx.strokePath()
    }
    boulder(center: CGPoint(x: s * 0.24, y: s * 0.80), radius: s * 0.075, hot: true, seed: &rng)
    boulder(center: CGPoint(x: s * 0.78, y: s * 0.84), radius: s * 0.055, hot: false, seed: &rng)
    boulder(center: CGPoint(x: s * 0.66, y: s * 0.62), radius: s * 0.04, hot: true, seed: &rng)

    // Embers / sparks.
    ctx.saveGState()
    ctx.setBlendMode(.screen)
    for _ in 0..<70 {
        let x = CGFloat(rng.range(0.05...0.95)) * s
        let y = CGFloat(rng.range(0.30...0.98)) * s
        let r = CGFloat(rng.range(2...7)) * u
        let a = CGFloat(rng.range(0.35...1.0))
        ctx.setFillColor(rgb(1.0, 0.7, 0.25, a * 0.35))
        ctx.fillEllipse(in: CGRect(x: x - r * 2.5, y: y - r * 2.5, width: r * 5, height: r * 5))
        ctx.setFillColor(rgb(1.0, 0.85, 0.5, a))
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    ctx.restoreGState()

    // Hero: small runner at the foot of the mountain.
    let hero = CGPoint(x: s * 0.50, y: s * 0.19)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 30 * u, color: rgb(1.0, 0.55, 0.2, 0.9))
    // Body capsule
    let body = CGPath(roundedRect: CGRect(x: hero.x - 34 * u, y: hero.y - 44 * u, width: 68 * u, height: 86 * u), cornerWidth: 32 * u, cornerHeight: 32 * u, transform: nil)
    ctx.addPath(body)
    ctx.setFillColor(rgb(0.80, 0.78, 0.82))
    ctx.fillPath()
    ctx.addPath(body)
    ctx.setStrokeColor(rgb(0.35, 0.33, 0.40))
    ctx.setLineWidth(6 * u)
    ctx.strokePath()
    // Head
    let headRect = CGRect(x: hero.x - 28 * u, y: hero.y + 36 * u, width: 56 * u, height: 56 * u)
    ctx.setFillColor(rgb(0.80, 0.78, 0.82))
    ctx.fillEllipse(in: headRect)
    ctx.setStrokeColor(rgb(0.35, 0.33, 0.40))
    ctx.strokeEllipse(in: headRect)
    // Visor
    ctx.setFillColor(rgb(1.0, 0.55, 0.2))
    ctx.addPath(CGPath(roundedRect: CGRect(x: hero.x - 18 * u, y: hero.y + 56 * u, width: 36 * u, height: 14 * u), cornerWidth: 7 * u, cornerHeight: 7 * u, transform: nil))
    ctx.fillPath()
    // Emblem
    ctx.move(to: CGPoint(x: hero.x, y: hero.y + 10 * u))
    ctx.addLine(to: CGPoint(x: hero.x + 10 * u, y: hero.y - 2 * u))
    ctx.addLine(to: CGPoint(x: hero.x, y: hero.y - 14 * u))
    ctx.addLine(to: CGPoint(x: hero.x - 10 * u, y: hero.y - 2 * u))
    ctx.closePath()
    ctx.fillPath()
    ctx.restoreGState()

    // Ground fissure.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 24 * u, color: rgb(1.0, 0.45, 0.12, 1))
    ctx.setStrokeColor(rgb(1.0, 0.5, 0.15))
    ctx.setLineWidth(6 * u)
    let fissure = CGMutablePath()
    fissure.move(to: CGPoint(x: 0, y: s * 0.12))
    var x: CGFloat = 0
    var up = true
    while x < s {
        x += CGFloat(rng.range(40...90)) * u
        fissure.addLine(to: CGPoint(x: x, y: s * 0.12 + (up ? 8 : -8) * u))
        up.toggle()
    }
    ctx.addPath(fissure)
    ctx.strokePath()
    ctx.restoreGState()

    return ctx
}

// MARK: - Sky Stack

func drawSkyStack(size: Int) -> CGContext {
    let ctx = makeContext(size)
    let s = CGFloat(size)
    let u = s / 1024
    var rng = Rng(state: 0xABCD_7777)

    // Sky gradient.
    ctx.drawLinearGradient(gradient([rgb(0.36, 0.70, 1.0), rgb(0.62, 0.86, 1.0), rgb(0.95, 0.80, 0.70)], [0, 0.6, 1]),
                           start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // Sun.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 60 * u, color: rgb(1.0, 0.9, 0.6, 0.9))
    ctx.setFillColor(rgb(1.0, 0.88, 0.55))
    ctx.fillEllipse(in: CGRect(x: s * 0.68, y: s * 0.70, width: s * 0.18, height: s * 0.18))
    ctx.restoreGState()

    // Clouds.
    func cloud(at c: CGPoint, scale: CGFloat, alpha: CGFloat) {
        ctx.setFillColor(rgb(1, 1, 1, alpha))
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [(0, 0, 70), (-70, -10, 50), (70, -8, 55), (-30, 30, 55), (35, 32, 50)]
        for (dx, dy, r) in blobs {
            let rr = r * scale * u
            ctx.fillEllipse(in: CGRect(x: c.x + dx * scale * u - rr, y: c.y + dy * scale * u - rr, width: rr * 2, height: rr * 2))
        }
    }
    cloud(at: CGPoint(x: s * 0.22, y: s * 0.78), scale: 1.0, alpha: 0.95)
    cloud(at: CGPoint(x: s * 0.80, y: s * 0.50), scale: 0.7, alpha: 0.85)
    cloud(at: CGPoint(x: s * 0.15, y: s * 0.42), scale: 0.55, alpha: 0.8)

    // Tower of blocks, slightly offset like a stacking game.
    let palette: [(CGColor, CGColor)] = [
        (rgb(0.98, 0.42, 0.40), rgb(0.75, 0.22, 0.25)),
        (rgb(1.00, 0.72, 0.30), rgb(0.85, 0.50, 0.12)),
        (rgb(0.45, 0.82, 0.45), rgb(0.22, 0.60, 0.30)),
        (rgb(0.35, 0.65, 0.98), rgb(0.15, 0.40, 0.80)),
        (rgb(0.72, 0.50, 0.95), rgb(0.48, 0.28, 0.75)),
        (rgb(0.98, 0.55, 0.75), rgb(0.80, 0.30, 0.55))
    ]
    let blockHeight = s * 0.105
    let baseWidth = s * 0.56
    var y = s * 0.06
    var centerX = s * 0.5
    let offsets: [CGFloat] = [0, 0.03, -0.025, 0.04, -0.03, 0.02, -0.015]
    for i in 0..<7 {
        let shrink = CGFloat(i) * 0.035
        let width = baseWidth * (1 - shrink)
        centerX = s * 0.5 + offsets[i] * s
        let rect = CGRect(x: centerX - width / 2, y: y, width: width, height: blockHeight)
        let (top, side) = palette[i % palette.count]
        // Shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 24 * u, color: rgb(0.1, 0.2, 0.4, 0.35))
        ctx.setFillColor(side)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 14 * u, cornerHeight: 14 * u, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
        // Face
        let face = rect.insetBy(dx: 0, dy: 0).offsetBy(dx: 0, dy: blockHeight * 0.18).divided(atDistance: blockHeight * 0.82, from: .minYEdge).slice
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: face, cornerWidth: 14 * u, cornerHeight: 14 * u, transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(gradient([top, side], [0, 1]), start: CGPoint(x: face.minX, y: face.maxY), end: CGPoint(x: face.minX, y: face.minY), options: [])
        // Highlight
        ctx.setFillColor(rgb(1, 1, 1, 0.35))
        ctx.fill(CGRect(x: face.minX, y: face.maxY - 10 * u, width: face.width, height: 10 * u))
        ctx.restoreGState()
        // Window dots
        ctx.setFillColor(rgb(1, 1, 1, 0.55))
        let dots = max(2, Int(width / (s * 0.12)))
        for d in 0..<dots {
            let dx = face.minX + face.width * (CGFloat(d) + 0.5) / CGFloat(dots)
            ctx.fillEllipse(in: CGRect(x: dx - 9 * u, y: face.midY - 9 * u, width: 18 * u, height: 18 * u))
        }
        y += blockHeight * 0.98
    }

    // Top block being lowered on a rope: dangling small block with crane line.
    let topWidth = baseWidth * (1 - 7 * 0.035)
    let hanging = CGRect(x: s * 0.5 - topWidth / 2 + s * 0.05, y: s * 0.86, width: topWidth, height: blockHeight)
    ctx.setStrokeColor(rgb(0.25, 0.25, 0.3, 0.8))
    ctx.setLineWidth(5 * u)
    ctx.move(to: CGPoint(x: hanging.midX, y: s))
    ctx.addLine(to: CGPoint(x: hanging.midX, y: hanging.maxY))
    ctx.strokePath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 24 * u, color: rgb(0.1, 0.2, 0.4, 0.35))
    ctx.addPath(CGPath(roundedRect: hanging, cornerWidth: 14 * u, cornerHeight: 14 * u, transform: nil))
    ctx.setFillColor(rgb(1.0, 0.85, 0.30))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(CGPath(roundedRect: hanging, cornerWidth: 14 * u, cornerHeight: 14 * u, transform: nil))
    ctx.setStrokeColor(rgb(0.85, 0.6, 0.1))
    ctx.setLineWidth(6 * u)
    ctx.strokePath()

    // Sparkles.
    ctx.setFillColor(rgb(1, 1, 1, 0.9))
    for _ in 0..<18 {
        let x = CGFloat(rng.range(0.05...0.95)) * s
        let yy = CGFloat(rng.range(0.15...0.95)) * s
        let r = CGFloat(rng.range(3...7)) * u
        ctx.fillEllipse(in: CGRect(x: x - r, y: yy - r, width: r * 2, height: r * 2))
    }

    return ctx
}

for size in [512, 1024] {
    save(drawMagmaRun(size: size), to: outputDirectory.appendingPathComponent("MagmaRun-\(size).png"))
    save(drawSkyStack(size: size), to: outputDirectory.appendingPathComponent("SkyStack-\(size).png"))
}
