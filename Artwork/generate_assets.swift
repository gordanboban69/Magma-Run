// Magma Run art generator.
// Paints every bitmap the game uses (skies, volcano, ground/lava tiles, boulders, heroes,
// effects, HUD, menu icons, tutorials, logo) with CoreGraphics and writes them as image
// sets into an asset catalog folder. Deterministic: the same run always produces the same art.
//
// Usage: swift Artwork/generate_assets.swift "MagmaRun/Assets.xcassets/Generated" [preview-dir]
// All drawing coordinates are in points; the canvas is points x 3 pixels (@3x).

import AppKit
import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Generated")
let previewRoot: URL? = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
let fm = FileManager.default
try? fm.createDirectory(at: outputRoot, withIntermediateDirectories: true)
if let previewRoot { try? fm.createDirectory(at: previewRoot, withIntermediateDirectories: true) }
try! #"{"info":{"author":"xcode","version":1}}"#.write(to: outputRoot.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Colour helpers

struct Col {
    var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1
    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(hex: UInt32, _ a: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255; self.a = a
    }
    var cg: CGColor { CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])! }
    func mix(_ o: Col, _ t: CGFloat) -> Col { Col(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t) }
    func alpha(_ v: CGFloat) -> Col { Col(r, g, b, v) }
    func lighter(_ t: CGFloat) -> Col { mix(Col(1, 0.97, 0.94, a), t) }
    func darker(_ t: CGFloat) -> Col { mix(Col(0.043, 0.024, 0.063, a), t) }
    static let white = Col(1, 1, 1)
    static let clear = Col(0, 0, 0, 0)
}

enum K {
    static let ink = Col(hex: 0x140A0E)
    static let obs0 = Col(hex: 0x0B0610), obs1 = Col(hex: 0x1C0E16), obs2 = Col(hex: 0x2E1420)
    static let basalt = Col(hex: 0x4A3E40), basaltD = Col(hex: 0x2A2022)
    static let molten = Col(hex: 0xFF6A1A), molten2 = Col(hex: 0xFF8A2A), hot = Col(hex: 0xFFD45A)
    static let crimson = Col(hex: 0xD6283A), ash = Col(hex: 0xB9A3B5)
    static let gold = Col(hex: 0xF2A93A)
}

struct Rng {
    var s: UInt64
    init(s: UInt64) { self.s = s &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> CGFloat {
        s ^= s >> 12; s ^= s << 25; s ^= s >> 27
        return CGFloat(Double((s &* 2685821657736338717) >> 11) / Double(1 << 53))
    }
    mutating func r(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

// MARK: - Geometry helpers

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
}
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }
func mixP(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { P(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t) }
func polar(_ c: CGPoint, _ r: CGFloat, _ a: CGFloat) -> CGPoint { P(c.x + cos(a) * r, c.y + sin(a) * r) }

// MARK: - Canvas (top-left origin, points)

let S: CGFloat = 3
var ctx: CGContext!
var canvasW: CGFloat = 0, canvasH: CGFloat = 0

func begin(_ w: CGFloat, _ h: CGFloat) {
    canvasW = w; canvasH = h
    let pw = Int(w * S), ph = Int(h * S)
    ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(ph)); ctx.scaleBy(x: 1, y: -1)
    ctx.scaleBy(x: S, y: S)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.interpolationQuality = .high
}

var generatedNames: [String] = []
/// Writes the current canvas as `<name>.imageset` marked @3x so 3 px = 1 pt.
func finish(_ name: String) {
    let image = ctx.makeImage()!
    let dir = outputRoot.appendingPathComponent("\(name).imageset")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("\(name).png")
    let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
    let json = #"{"images":[{"idiom":"universal","scale":"1x"},{"idiom":"universal","scale":"2x"},{"filename":"\#(name).png","idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}"#
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    if let previewRoot { try? fm.removeItem(at: previewRoot.appendingPathComponent("\(name).png")); try? fm.copyItem(at: file, to: previewRoot.appendingPathComponent("\(name).png")) }
    generatedNames.append(name)
}

func gradient(_ cols: [Col], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: cols.map(\.cg) as CFArray, locations: locs)!
}

func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: min(radius, r.width / 2), cornerHeight: min(radius, r.height / 2), transform: nil) }
func ellipse(_ r: CGRect) -> CGPath { CGPath(ellipseIn: r, transform: nil) }
func circle(_ c: CGPoint, _ rad: CGFloat) -> CGPath { ellipse(CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)) }
func poly(_ pts: [CGPoint]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p }
func line(_ pts: [CGPoint]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts); return p }
func rectPath(_ r: CGRect) -> CGPath { CGPath(rect: r, transform: nil) }
func moved(_ p: CGPath, _ dx: CGFloat, _ dy: CGFloat) -> CGPath { var t = CGAffineTransform(translationX: dx, y: dy); return p.copy(using: &t)! }

func fill(_ path: CGPath, _ c: Col) { ctx.addPath(path); ctx.setFillColor(c.cg); ctx.fillPath() }
func stroke(_ path: CGPath, _ c: Col, _ w: CGFloat) { ctx.addPath(path); ctx.setStrokeColor(c.cg); ctx.setLineWidth(w); ctx.strokePath() }
func linearFill(_ path: CGPath, _ cols: [Col], _ from: CGPoint, _ to: CGPoint, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(gradient(cols, locs), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
func radialFill(_ path: CGPath, _ cols: [Col], _ c: CGPoint, _ radius: CGFloat, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawRadialGradient(gradient(cols, locs), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}
func glow(_ c: CGPoint, _ radius: CGFloat, _ col: Col) {
    ctx.saveGState(); ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([col, col.alpha(col.a * 0.35), col.alpha(0)], [0, 0.4, 1]), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    ctx.restoreGState()
}
/// Normal-blend radial glow (works on transparent canvases where screen would vanish against nothing).
func halo(_ c: CGPoint, _ radius: CGFloat, _ col: Col) {
    ctx.drawRadialGradient(gradient([col, col.alpha(col.a * 0.35), col.alpha(0)], [0, 0.45, 1]), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
}
func shadowed(_ offsetY: CGFloat, _ blur: CGFloat, _ col: Col = Col(0.02, 0, 0.02, 0.5), dx: CGFloat = 0, _ body: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: dx * S, height: -offsetY * S), blur: blur * S, color: col.cg); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer(); ctx.restoreGState()
}
func clipped(_ path: CGPath, _ body: () -> Void) { ctx.saveGState(); ctx.addPath(path); ctx.clip(); body(); ctx.restoreGState() }
func layer(_ body: () -> Void) { ctx.beginTransparencyLayer(auxiliaryInfo: nil); body(); ctx.endTransparencyLayer() }
func withT(_ x: CGFloat, _ y: CGFloat, scale: CGFloat = 1, rot: CGFloat = 0, _ body: () -> Void) {
    ctx.saveGState(); ctx.translateBy(x: x, y: y); ctx.rotate(by: rot); ctx.scaleBy(x: scale, y: scale); body(); ctx.restoreGState()
}
/// Current user->device scale (for shadow parameters, which live in device space).
func devScale() -> CGFloat { let t = ctx.ctm; return sqrt(abs(t.a * t.d - t.b * t.c)) }

/// Blurred fill: draws the shape far off-canvas and only its shadow lands on the canvas.
func softFill(_ path: CGPath, _ col: Col, blur: CGFloat) {
    ctx.saveGState()
    let ds = devScale(), D: CGFloat = 5000
    ctx.setShadow(offset: CGSize(width: D * ds, height: 0), blur: blur * ds, color: col.cg)
    ctx.translateBy(x: -D, y: 0)
    fill(path, Col(0, 0, 0, 1))
    ctx.restoreGState()
}
func softStroke(_ path: CGPath, _ col: Col, _ w: CGFloat, blur: CGFloat) {
    ctx.saveGState()
    let ds = devScale(), D: CGFloat = 5000
    ctx.setShadow(offset: CGSize(width: D * ds, height: 0), blur: blur * ds, color: col.cg)
    ctx.translateBy(x: -D, y: 0)
    stroke(path, Col(0, 0, 0, 1), w)
    ctx.restoreGState()
}
/// Light crescent on one edge: fills the shape, then erases a softened copy shifted by (dx, dy).
/// A shift up-left leaves a crescent on the bottom-right edge (rim light), down-right leaves a top-left highlight.
func edgeLight(_ path: CGPath, _ col: Col, _ dx: CGFloat, _ dy: CGFloat, blur: CGFloat = 0) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    fill(path, col)
    ctx.setBlendMode(.destinationOut)
    if blur > 0 { ctx.setShadow(offset: .zero, blur: blur * devScale(), color: Col(0, 0, 0, 1).cg) }
    ctx.translateBy(x: dx, y: dy)
    fill(path, Col(0, 0, 0, 1))
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

/// Standard object shading: top-left lit gradient, soft highlight, molten rim on the bottom-right, warm dark outline.
func paint(_ path: CGPath, _ base: Col, ow: CGFloat, rim: CGFloat = 0.55, hi: CGFloat = 0.22, rimCol: Col = K.molten2, light: CGFloat = 0.22, dark: CGFloat = 0.4) {
    let b = path.boundingBox
    let d = max(0.5, min(b.width, b.height) * 0.13)
    linearFill(path, [base.lighter(light), base, base.darker(dark)], P(b.minX, b.minY), P(b.maxX, b.maxY), [0, 0.45, 1])
    if hi > 0 { edgeLight(path, Col(1, 0.96, 0.92, hi), d, d, blur: d * 0.7) }
    if rim > 0 { edgeLight(path, rimCol.alpha(rim), -d * 0.9, -d * 0.9, blur: d * 0.6) }
    if ow > 0 { stroke(path, K.ink, ow) }
}

let ciContext = CIContext(options: nil)
/// Draws `body` into an offscreen copy of the canvas, gaussian-blurs it, and composites it back (soft painterly smoke).
func blurredLayer(_ blur: CGFloat, alpha: CGFloat = 1, _ body: () -> Void) {
    let main = ctx!
    let pw = main.width, ph = main.height
    let off = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    off.concatenate(main.ctm)
    off.setLineCap(.round); off.setLineJoin(.round)
    let sigma = blur * sqrt(abs(main.ctm.a * main.ctm.d - main.ctm.b * main.ctm.c))
    ctx = off; body(); ctx = main
    let src = CIImage(cgImage: off.makeImage()!)
    let blurred = src.clampedToExtent().applyingGaussianBlur(sigma: Double(sigma)).cropped(to: src.extent)
    let img = ciContext.createCGImage(blurred, from: src.extent)!
    main.saveGState()
    main.concatenate(main.ctm.inverted())
    main.setAlpha(alpha)
    main.draw(img, in: CGRect(x: 0, y: 0, width: pw, height: ph))
    main.restoreGState()
}

/// Appends smooth curves through pts to a path whose current point is already pts[0].
func appendSmooth(_ p: CGMutablePath, _ pts: [CGPoint], _ t: CGFloat = 1) {
    for i in 0..<(pts.count - 1) {
        let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
        let c1 = P(p1.x + (p2.x - p0.x) / 6 * t, p1.y + (p2.y - p0.y) / 6 * t)
        let c2 = P(p2.x - (p3.x - p1.x) / 6 * t, p2.y - (p3.y - p1.y) / 6 * t)
        p.addCurve(to: p2, control1: c1, control2: c2)
    }
}

func smoothClosed(_ pts: [CGPoint], _ t: CGFloat = 1) -> CGPath {
    let n = pts.count
    let p = CGMutablePath(); p.move(to: pts[0])
    for i in 0..<n {
        let p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n]
        let c1 = P(p1.x + (p2.x - p0.x) / 6 * t, p1.y + (p2.y - p0.y) / 6 * t)
        let c2 = P(p2.x - (p3.x - p1.x) / 6 * t, p2.y - (p3.y - p1.y) / 6 * t)
        p.addCurve(to: p2, control1: c1, control2: c2)
    }
    p.closeSubpath()
    return p
}
func smoothOpen(_ pts: [CGPoint], _ t: CGFloat = 1) -> CGPath {
    let p = CGMutablePath(); p.move(to: pts[0])
    if pts.count == 2 { p.addLine(to: pts[1]); return p }
    for i in 0..<(pts.count - 1) {
        let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
        let c1 = P(p1.x + (p2.x - p0.x) / 6 * t, p1.y + (p2.y - p0.y) / 6 * t)
        let c2 = P(p2.x - (p3.x - p1.x) / 6 * t, p2.y - (p3.y - p1.y) / 6 * t)
        p.addCurve(to: p2, control1: c1, control2: c2)
    }
    return p
}
/// Samples a Catmull-Rom spline through the points.
func spline(_ pts: [CGPoint], _ per: Int = 10) -> [CGPoint] {
    var out: [CGPoint] = []
    for i in 0..<(pts.count - 1) {
        let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
        for k in 0..<per {
            let t = CGFloat(k) / CGFloat(per), t2 = t * t, t3 = t2 * t
            func f(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                let q1 = 2 * b, q2 = (c - a) * t
                let q3 = (2 * a - 5 * b + 4 * c - d) * t2
                let q4 = (3 * b - a - 3 * c + d) * t3
                return 0.5 * (q1 + q2 + q3 + q4)
            }
            out.append(P(f(p0.x, p1.x, p2.x, p3.x), f(p0.y, p1.y, p2.y, p3.y)))
        }
    }
    out.append(pts.last!)
    return out
}
/// A filled ribbon along a polyline with width varying along its length.
func ribbon(_ pts: [CGPoint], _ w: (CGFloat) -> CGFloat) -> CGPath {
    var left: [CGPoint] = [], right: [CGPoint] = []
    let n = pts.count
    for i in 0..<n {
        let a = pts[max(i - 1, 0)], b = pts[min(i + 1, n - 1)]
        let dx = b.x - a.x, dy = b.y - a.y, l = max(hypot(dx, dy), 0.001)
        let hw = w(CGFloat(i) / CGFloat(n - 1)) / 2
        left.append(P(pts[i].x - dy / l * hw, pts[i].y + dx / l * hw))
        right.append(P(pts[i].x + dy / l * hw, pts[i].y - dx / l * hw))
    }
    return smoothClosed(left + right.reversed(), 0.6)
}
func blobPoints(_ c: CGPoint, _ r: CGFloat, n: Int, seed: UInt64, jitter: CGFloat, sx: CGFloat = 1, sy: CGFloat = 1, rot: CGFloat = 0) -> [CGPoint] {
    var g = Rng(s: seed)
    var pts: [CGPoint] = []
    for i in 0..<n {
        let a = rot + CGFloat(i) / CGFloat(n) * .pi * 2 + g.r(-0.12, 0.12)
        let rad = r * (1 + g.r(-jitter, jitter))
        pts.append(P(c.x + cos(a) * rad * sx, c.y + sin(a) * rad * sy))
    }
    return pts
}
func blob(_ c: CGPoint, _ r: CGFloat, n: Int = 8, seed: UInt64, jitter: CGFloat = 0.25, sx: CGFloat = 1, sy: CGFloat = 1, rot: CGFloat = 0, t: CGFloat = 1) -> CGPath {
    smoothClosed(blobPoints(c, r, n: n, seed: seed, jitter: jitter, sx: sx, sy: sy, rot: rot), t)
}
func star(_ c: CGPoint, _ outer: CGFloat, _ inner: CGFloat, points: Int = 5, rotation: CGFloat = -.pi / 2) -> CGPath {
    var pts: [CGPoint] = []
    for i in 0..<(points * 2) {
        let a = rotation + CGFloat(i) * .pi / CGFloat(points)
        pts.append(polar(c, i % 2 == 0 ? outer : inner, a))
    }
    return poly(pts)
}
/// Teardrop with the tip pointing up; `c` is the centre of the round part.
func dropPath(_ c: CGPoint, _ r: CGFloat, tip: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: P(c.x, c.y - tip))
    p.addCurve(to: P(c.x + r, c.y), control1: P(c.x + r * 0.2, c.y - tip * 0.55), control2: P(c.x + r, c.y - r * 0.8))
    p.addArc(center: c, radius: r, startAngle: 0, endAngle: .pi, clockwise: false)
    p.addCurve(to: P(c.x, c.y - tip), control1: P(c.x - r, c.y - r * 0.8), control2: P(c.x - r * 0.2, c.y - tip * 0.55))
    p.closeSubpath()
    return p
}
/// Flame tongue rising from `base` (bottom centre).
func flamePath(_ base: CGPoint, _ w: CGFloat, _ h: CGFloat, lean: CGFloat = 0) -> CGPath {
    let p = CGMutablePath()
    let tip = P(base.x + lean, base.y - h)
    p.move(to: tip)
    p.addCurve(to: P(base.x + w * 0.5, base.y - h * 0.32), control1: P(base.x + lean * 0.4 + w * 0.12, base.y - h * 0.7), control2: P(base.x + w * 0.55, base.y - h * 0.55))
    p.addCurve(to: P(base.x, base.y), control1: P(base.x + w * 0.48, base.y - h * 0.08), control2: P(base.x + w * 0.28, base.y))
    p.addCurve(to: P(base.x - w * 0.5, base.y - h * 0.32), control1: P(base.x - w * 0.28, base.y), control2: P(base.x - w * 0.48, base.y - h * 0.08))
    p.addCurve(to: tip, control1: P(base.x - w * 0.55, base.y - h * 0.58), control2: P(base.x + lean * 0.5 - w * 0.05, base.y - h * 0.75))
    p.closeSubpath()
    return p
}
func heartPath(_ c: CGPoint, _ s: CGFloat) -> CGPath {
    var pts: [CGPoint] = []
    for i in 0..<72 {
        let t = CGFloat(i) / 72 * .pi * 2
        let x = 16 * pow(sin(t), 3)
        let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
        pts.append(P(c.x + x / 16 * s, c.y - (y + 2) / 16 * s))
    }
    return poly(pts)
}

// MARK: - Shared motifs: flame, ember, glow sparks

func drawFlame(_ base: CGPoint, _ w: CGFloat, _ h: CGFloat, lean: CGFloat = 0, ow: CGFloat = 0, alpha: CGFloat = 1) {
    let outer = flamePath(base, w, h, lean: lean)
    linearFill(outer, [K.hot.alpha(alpha), K.molten2.alpha(alpha), K.molten.alpha(alpha), K.crimson.alpha(alpha)], P(base.x, base.y), P(base.x, base.y - h), [0, 0.3, 0.6, 1])
    if ow > 0 { stroke(outer, K.ink.alpha(alpha * 0.9), ow) }
    let inner = flamePath(P(base.x, base.y - h * 0.04), w * 0.5, h * 0.6, lean: lean * 0.5)
    linearFill(inner, [Col(1, 0.98, 0.85, alpha), K.hot.alpha(alpha)], P(base.x, base.y), P(base.x, base.y - h * 0.6))
}

func spark(_ c: CGPoint, _ r: CGFloat, _ col: Col = K.hot) {
    halo(c, r * 4, col.alpha(col.a * 0.45))
    fill(star(c, r * 1.6, r * 0.35, points: 4, rotation: 0), Col(1, 0.95, 0.8, col.a))
}

/// Ember: a faceted flame-drop crystal. `crisp` = thicker outline and less halo for icons.
func drawEmber(_ c: CGPoint, _ r: CGFloat, crisp: Bool = false, glowAmount: CGFloat = 1) {
    let tip = r * 2.25
    let body = dropPath(P(c.x, c.y + r * 0.42), r * 0.78, tip: tip * 0.82)
    if glowAmount > 0 { halo(P(c.x, c.y + r * 0.15), r * (crisp ? 1.5 : 2.2), K.molten.alpha(0.6 * glowAmount)) }
    let b = body.boundingBox
    linearFill(body, [K.hot, K.molten2, K.molten, K.crimson], P(b.minX, b.minY), P(b.maxX, b.maxY), [0, 0.3, 0.65, 1])
    // facets
    let cc = P(c.x - r * 0.08, c.y + r * 0.3)
    let top = P(c.x, b.minY + r * 0.05)
    clipped(body) {
        fill(poly([top, cc, P(b.minX - 1, c.y + r * 0.2), P(b.minX, b.minY)]), Col(1, 0.95, 0.7, 0.45))
        fill(poly([cc, P(b.minX - 1, c.y + r * 0.2), P(b.minX, b.maxY + 1), P(c.x, b.maxY + 1)]), Col(1, 0.8, 0.4, 0.25))
        fill(poly([top, cc, P(b.maxX + 1, c.y + r * 0.5), P(b.maxX, b.minY)]), Col(0.6, 0.05, 0.05, 0.18))
        fill(poly([cc, P(b.maxX + 1, c.y + r * 0.5), P(b.maxX, b.maxY + 1), P(c.x, b.maxY + 1)]), Col(0.45, 0, 0.05, 0.32))
        fill(circle(P(c.x - r * 0.12, c.y + r * 0.45), r * 0.32), Col(1, 1, 0.85, 0.75))
    }
    edgeLight(body, K.crimson.darker(0.3).alpha(0.6), -r * 0.12, -r * 0.12, blur: r * 0.08)
    stroke(body, K.ink, crisp ? r * 0.16 : r * 0.1)
    fill(ellipse(R(c.x - r * 0.42, c.y - r * 0.55, r * 0.22, r * 0.5)), Col(1, 1, 0.95, 0.85))
}

func drawHeartShard(_ c: CGPoint, _ s: CGFloat, crisp: Bool = false, glowAmount: CGFloat = 1) {
    // A heart broken along a jagged diagonal: we draw the left lobe piece (the shard) with a sliver gap.
    let heart = heartPath(c, s)
    if glowAmount > 0 { halo(c, s * (crisp ? 1.5 : 2.0), K.crimson.alpha(0.55 * glowAmount)) }
    let cut = poly([P(c.x + s * 0.18, c.y - s * 1.2), P(c.x + s * 0.02, c.y - s * 0.45), P(c.x + s * 0.3, c.y - s * 0.1), P(c.x + s * 0.06, c.y + s * 0.35), P(c.x + s * 0.24, c.y + s * 1.2),
                    P(c.x - s * 1.5, c.y + s * 1.5), P(c.x - s * 1.5, c.y - s * 1.5)])
    ctx.saveGState(); ctx.addPath(cut); ctx.clip()
    let b = heart.boundingBox
    linearFill(heart, [Col(hex: 0xFF8A9A), Col(hex: 0xF0304A), Col(hex: 0xA01028), Col(hex: 0x5A0618)], P(b.minX, b.minY), P(b.maxX, b.maxY), [0, 0.3, 0.7, 1])
    clipped(heart) {
        let cc = P(c.x - s * 0.35, c.y + s * 0.05)
        fill(poly([cc, P(c.x - s * 1.1, c.y - s * 0.4), P(c.x - s * 0.6, c.y - s * 1.1), P(c.x, c.y - s * 0.6)]), Col(1, 0.8, 0.85, 0.35))
        fill(poly([cc, P(c.x - s * 1.1, c.y - s * 0.4), P(c.x - s * 1.0, c.y + s * 0.4), P(c.x - s * 0.1, c.y + s * 1.2)]), Col(0.4, 0, 0.1, 0.2))
        fill(poly([cc, P(c.x, c.y - s * 0.6), P(c.x + s * 0.3, c.y + s * 0.2), P(c.x - s * 0.1, c.y + s * 1.2)]), Col(0.3, 0, 0.05, 0.35))
        fill(circle(P(c.x - s * 0.4, c.y + s * 0.15), s * 0.18), Col(1, 0.9, 0.9, 0.5))
    }
    ctx.restoreGState()
    let shard = CGMutablePath()
    // outline only around the visible piece: intersect via clipping the stroke
    ctx.saveGState(); ctx.addPath(cut); ctx.clip()
    stroke(heart, K.ink, crisp ? s * 0.16 : s * 0.11)
    ctx.restoreGState()
    let edge = line([P(c.x + s * 0.18, c.y - s * 0.86), P(c.x + s * 0.02, c.y - s * 0.45), P(c.x + s * 0.3, c.y - s * 0.1), P(c.x + s * 0.06, c.y + s * 0.35), P(c.x + s * 0.18, c.y + s * 0.78)])
    clipped(heart) { stroke(edge, K.ink, crisp ? s * 0.14 : s * 0.1) }
    _ = shard
    fill(ellipse(R(c.x - s * 0.85, c.y - s * 0.7, s * 0.28, s * 0.42)), Col(1, 1, 1, 0.8))
}

// MARK: - Tileable terrain (200 x 120 pt)

let tileW: CGFloat = 200, tileH: CGFloat = 120

/// A jagged periodic line across the tile at height y.
func periodicLine(_ y: CGFloat, amp: CGFloat, n: Int, seed: UInt64, w: CGFloat = tileW) -> [CGPoint] {
    var g = Rng(s: seed)
    var pts: [CGPoint] = []
    for i in 0..<n {
        let x = CGFloat(i) / CGFloat(n) * w + (i == 0 ? 0 : g.r(-w / CGFloat(n) * 0.3, w / CGFloat(n) * 0.3))
        pts.append(P(x, y + g.r(-amp, amp)))
    }
    pts.append(P(pts[0].x + w, pts[0].y))
    return pts
}
func extended(_ pts: [CGPoint], _ w: CGFloat) -> [CGPoint] {
    let n = pts.count - 1
    var out: [CGPoint] = []
    for k in -1...1 { for i in 0..<n { out.append(P(pts[i].x + CGFloat(k) * w, pts[i].y)) } }
    out.append(P(pts[0].x + 2 * w, pts[0].y))
    return out
}

func drawGroundTile() {
    let W = tileW, H = tileH
    linearFill(rectPath(R(0, 0, W, H)), [Col(hex: 0x3A2A2C), K.basaltD, Col(hex: 0x1E1418), K.obs1, K.obs0], P(0, 0), P(0, H), [0, 0.12, 0.4, 0.75, 1])
    var g = Rng(s: 11)
    // strata bands (integer periods keep them tileable)
    for k in 0..<6 {
        let y0 = 26 + CGFloat(k) * 16, ph = g.r(0, 6), f = CGFloat(Int(g.r(1, 4)))
        var pts: [CGPoint] = []
        for i in 0...60 { let x = CGFloat(i) / 60 * W; pts.append(P(x, y0 + 2.5 * sin(x / W * .pi * 2 * f + ph) + 1.2 * sin(x / W * .pi * 2 * (f + 2) + ph * 2))) }
        stroke(line(pts), Col(0, 0, 0, 0.28), 1.4)
        stroke(moved(line(pts), 0, 1.2), Col(0.75, 0.55, 0.55, 0.07), 0.8)
    }
    // pebbles and speckles
    struct Peb { let c: CGPoint; let r: CGFloat; let seed: UInt64 }
    var pebs: [Peb] = []
    for i in 0..<26 { pebs.append(Peb(c: P(g.r(0, W), g.r(24, H - 4)), r: g.r(1.6, 4.6), seed: UInt64(300 + i))) }
    var specks: [(CGPoint, CGFloat, CGFloat)] = []
    for _ in 0..<220 { specks.append((P(g.r(0, W), g.r(14, H)), g.r(0.3, 0.9), g.r(-1, 1))) }
    for o in [-W, 0, W] {
        for s in specks { fill(circle(P(s.0.x + o, s.0.y), s.1), s.2 > 0 ? Col(0.6, 0.45, 0.45, 0.18) : Col(0, 0, 0, 0.3)) }
        for p in pebs {
            let path = blob(P(p.c.x + o, p.c.y), p.r, n: 6, seed: p.seed, jitter: 0.25, sx: 1.3, sy: 0.8, t: 0.7)
            fill(moved(path, 0.6, 0.9), Col(0, 0, 0, 0.45))
            paint(path, K.basalt.mix(K.basaltD, CGFloat(p.seed % 3) * 0.3), ow: 0.5, rim: 0.12, hi: 0.3)
        }
    }
    // top crust band above the fissure
    let fis = periodicLine(8, amp: 2.4, n: 20, seed: 12)
    let ext = extended(fis, W)
    let lip = poly([P(-W, -1)] + ext.map { P($0.x, $0.y - 1.2) } + [P(2 * W, -1)])
    linearFill(lip, [Col(hex: 0x5A4446), Col(hex: 0x3E2E30)], P(0, 0), P(0, 9))
    stroke(line([P(-W, 0.6), P(2 * W, 0.6)]), Col(0.9, 0.7, 0.65, 0.25), 1.2)
    // glowing fissure: soft glow, molten body, hot core
    let fl = line(ext)
    softStroke(fl, K.molten.alpha(0.9), 5, blur: 5)
    linearFill(rectPath(R(0, 8, W, 10)), [K.molten.alpha(0.28), K.molten.alpha(0)], P(0, 8), P(0, 18))
    stroke(fl, Col(hex: 0x8A1E10), 3.4)
    stroke(fl, K.molten, 2.3)
    stroke(fl, K.hot, 1.0)
    // small branches
    var bg = Rng(s: 13)
    var branches: [[CGPoint]] = []
    for i in 0..<7 {
        let base = fis[Int(bg.r(0, CGFloat(fis.count - 2)))]
        var pts = [base]; var p = base
        for _ in 0..<3 { p = P(p.x + bg.r(-4, 4), p.y + bg.r(2, 4)); pts.append(p) }
        _ = i; branches.append(pts)
    }
    for o in [-W, 0, W] {
        for b in branches {
            let path = line(b.map { P($0.x + o, $0.y) })
            softStroke(path, K.molten.alpha(0.6), 1.5, blur: 2)
            stroke(path, K.molten.alpha(0.85), 0.9)
        }
    }
}

func drawLavaTile() {
    let W = tileW, H = tileH
    var edge: [CGPoint] = []
    for i in 0...80 {
        let x = CGFloat(i) / 80 * W
        edge.append(P(x, 5 + 1.6 * sin(x / W * .pi * 6) + 0.9 * sin(x / W * .pi * 14 + 1)))
    }
    let surface = poly([P(0, H + 1)] + edge + [P(W, H + 1)])
    linearFill(surface, [Col(1, 0.95, 0.7), K.hot, K.molten2, K.molten, Col(hex: 0xC2341A), Col(hex: 0x8A1A12)], P(0, 3), P(0, H), [0, 0.05, 0.2, 0.5, 0.8, 1])
    clipped(surface) {
        var g = Rng(s: 21)
        // flow bands
        for k in 0..<7 {
            let y0 = 16 + CGFloat(k) * 15, f = CGFloat(Int(g.r(1, 3))), ph = g.r(0, 6)
            var pts: [CGPoint] = []
            for i in 0...60 { let x = CGFloat(i) / 60 * W; pts.append(P(x, y0 + 3 * sin(x / W * .pi * 2 * f + ph))) }
            stroke(line(pts), Col(0.75, 0.15, 0.05, 0.22), 3)
            stroke(moved(line(pts), 0, -1.6), Col(1, 0.9, 0.5, 0.25), 1)
        }
        struct Plate { let c: CGPoint; let r: CGFloat; let sx: CGFloat; let seed: UInt64 }
        var plates: [Plate] = []
        for i in 0..<10 { plates.append(Plate(c: P(g.r(0, W), g.r(22, H + 6)), r: g.r(7, 15), sx: g.r(1.5, 2.6), seed: UInt64(400 + i))) }
        var swirls: [[CGPoint]] = []
        for _ in 0..<9 {
            let x0 = g.r(0, W), y0 = g.r(14, H - 8)
            var pts: [CGPoint] = []
            for k in 0..<5 { pts.append(P(x0 + CGFloat(k) * 9, y0 + 3 * sin(CGFloat(k) * 1.4 + x0))) }
            swirls.append(pts)
        }
        var spots: [(CGPoint, CGFloat)] = []
        for _ in 0..<26 { spots.append((P(g.r(0, W), g.r(10, H)), g.r(0.8, 2.2))) }
        for o in [-W, 0, W] {
            for s in swirls { let p = smoothOpen(s.map { P($0.x + o, $0.y) }); stroke(p, Col(1, 0.93, 0.6, 0.75), 1.3) }
            for p in plates {
                let path = blob(P(p.c.x + o, p.c.y), p.r, n: 7, seed: p.seed, jitter: 0.35, sx: p.sx, sy: 0.5)
                softStroke(path, K.hot.alpha(0.9), 2.2, blur: 2.5)
                let b = path.boundingBox
                linearFill(path, [Col(hex: 0x4A2A26), K.obs2, K.obs1], P(b.minX, b.minY), P(b.maxX, b.maxY))
                clipped(path) {
                    for k in 0..<3 { let yy = b.minY + b.height * (0.3 + CGFloat(k) * 0.22); stroke(line([P(b.minX, yy), P(b.maxX, yy + 1)]), Col(1, 0.4, 0.1, 0.35), 0.6) }
                }
                edgeLight(path, K.molten.alpha(0.8), -1.2, -1.4, blur: 0.8)
                edgeLight(path, Col(1, 0.9, 0.8, 0.2), 1, 1, blur: 0.6)
            }
            for s in spots { fill(circle(P(s.0.x + o, s.0.y), s.1), Col(1, 0.97, 0.8, 0.8)); halo(P(s.0.x + o, s.0.y), s.1 * 3, K.hot.alpha(0.4)) }
        }
    }
    let top = line(edge)
    stroke(top, Col(1, 0.97, 0.85, 0.95), 1.6)
    softStroke(top, K.hot.alpha(0.8), 3, blur: 3)
}

func drawCrustTile() {
    let W = tileW, H = tileH
    // crack bed
    linearFill(rectPath(R(0, 0, W, H)), [Col(hex: 0x3A1410), Col(hex: 0x220A0C)], P(0, 0), P(0, H))
    var g = Rng(s: 31)
    let nx = 5
    let rowY: [CGFloat] = [-6, 26, 58, 88, 126]
    var lattice: [[CGPoint]] = []
    for j in 0..<rowY.count {
        var row: [CGPoint] = []
        var first = CGPoint.zero
        for i in 0...nx {
            if i == nx { row.append(P(first.x + W, first.y)); continue }
            let jx = (j == 0 || j == rowY.count - 1) ? g.r(-6, 6) : g.r(-11, 11)
            let p = P(CGFloat(i) * W / CGFloat(nx) + jx + (j % 2 == 0 ? 0 : 20), rowY[j] + g.r(-6, 6))
            if i == 0 { first = p }
            row.append(p)
        }
        lattice.append(row)
    }
    func cellPath(_ i: Int, _ j: Int, _ o: CGFloat) -> CGPath {
        let a = lattice[j][i], b = lattice[j][i + 1], c = lattice[j + 1][i + 1], d = lattice[j + 1][i]
        // offset rows shift by half a cell: pair top/bottom by nearest index
        let pts = [a, b, c, d].map { P($0.x + o, $0.y) }
        let cx = pts.reduce(0) { $0 + $1.x } / 4, cy = pts.reduce(0) { $0 + $1.y } / 4
        let shrunk = pts.map { p -> CGPoint in let dx = p.x - cx, dy = p.y - cy, l = max(hypot(dx, dy), 0.01); return P(p.x - dx / l * 1.6, p.y - dy / l * 1.6) }
        return smoothClosed(shrunk, 0.25)
    }
    // faint orange glow inside the cracks
    for o in [-W, 0, W] {
        for j in 0..<(rowY.count - 1) {
            for i in 0..<nx {
                let path = cellPath(i, j, o)
                softStroke(path, K.molten.alpha(0.55), 2.4, blur: 2.5)
            }
        }
    }
    for o in [-W, 0, W] {
        for j in 0..<(rowY.count - 1) {
            for i in 0..<nx {
                let path = cellPath(i, j, o)
                let b = path.boundingBox
                let tone = CGFloat((i * 7 + j * 3) % 4) * 0.025
                linearFill(path, [Col(0.17 + tone, 0.13 + tone, 0.2 + tone), Col(hex: 0x120A14), Col(hex: 0x07040A)], P(b.minX, b.minY), P(b.maxX, b.maxY), [0, 0.5, 1])
                clipped(path) {
                    // glossy specular streak
                    let sx = b.minX + b.width * 0.25
                    fill(poly([P(sx, b.minY - 2), P(sx + 14, b.minY - 2), P(sx - 6, b.maxY + 2), P(sx - 16, b.maxY + 2)]), Col(1, 0.95, 1, 0.07))
                    fill(poly([P(sx + 18, b.minY - 2), P(sx + 22, b.minY - 2), P(sx + 2, b.maxY + 2), P(sx - 2, b.maxY + 2)]), Col(1, 0.95, 1, 0.08))
                    // hairline cracks
                    var cg = Rng(s: UInt64(500 + i * 10 + j))
                    let cs = P(b.midX + cg.r(-8, 8), b.midY + cg.r(-6, 6))
                    let cp = line([cs, P(cs.x + cg.r(-12, 12), cs.y + cg.r(-10, 10)), P(cs.x + cg.r(-20, 20), cs.y + cg.r(-14, 14))])
                    stroke(cp, K.molten.alpha(0.4), 0.6)
                }
                edgeLight(path, Col(0.95, 0.85, 1, 0.3), 1.2, 1.2, blur: 1)
                edgeLight(path, K.molten.alpha(0.35), -1.3, -1.3, blur: 1)
                stroke(path, Col(hex: 0x05020A), 0.7)
                fill(ellipse(R(b.minX + b.width * 0.18, b.minY + b.height * 0.16, 5, 2.2)), Col(1, 1, 1, 0.35))
            }
        }
    }
    stroke(line([P(-1, 0.8), P(W + 1, 0.8)]), Col(0.9, 0.8, 1, 0.2), 1.4)
}

func drawCrackTile() {
    let W = tileW
    var g = Rng(s: 41)
    var cracks: [[CGPoint]] = []
    let mains = [periodicLine(12, amp: 4, n: 14, seed: 42), periodicLine(56, amp: 6, n: 10, seed: 43), periodicLine(96, amp: 6, n: 10, seed: 44)]
    var branches: [[CGPoint]] = []
    for m in mains {
        for _ in 0..<5 {
            let s = m[Int(g.r(0, CGFloat(m.count - 2)))]
            var p = s; var pts = [s]
            let dir: CGFloat = g.next() > 0.5 ? 1 : -1
            for _ in 0..<Int(g.r(3, 6)) { p = P(p.x + g.r(-6, 6), p.y + dir * g.r(3, 7)); pts.append(p) }
            branches.append(pts)
        }
    }
    cracks = mains
    for o in [-W, 0, W] {
        for (k, m) in cracks.enumerated() {
            let path = line(m.map { P($0.x + o, $0.y) })
            let w: CGFloat = k == 0 ? 2.4 : 1.8
            softStroke(path, K.molten.alpha(0.95), w * 3, blur: 5)
            stroke(path, Col(hex: 0x8A1E10, 0.9), w + 1.2)
            stroke(path, K.molten, w)
            stroke(path, K.hot, w * 0.4)
        }
        for b in branches {
            let path = line(b.map { P($0.x + o, $0.y) })
            softStroke(path, K.molten.alpha(0.8), 3, blur: 3)
            stroke(path, K.molten, 1.1)
            stroke(path, K.hot.alpha(0.8), 0.45)
        }
    }
}

// MARK: - Boulders

struct RockShape { let n: Int; let jit: CGFloat; let sx: CGFloat; let sy: CGFloat; let ten: CGFloat; let rot: CGFloat }
let rockShapes: [RockShape] = [
    RockShape(n: 11, jit: 0.07, sx: 1.0, sy: 0.94, ten: 1.0, rot: 0.2),
    RockShape(n: 7, jit: 0.1, sx: 1.12, sy: 0.8, ten: 0.55, rot: 0.3),
    RockShape(n: 6, jit: 0.08, sx: 1.0, sy: 0.98, ten: 0.32, rot: 0.55),
    RockShape(n: 9, jit: 0.22, sx: 0.9, sy: 1.05, ten: 0.7, rot: 1.1)
]

func boulderPath(_ c: CGPoint, _ r: CGFloat, _ idx: Int) -> CGPath {
    let s = rockShapes[idx % 4]
    return smoothClosed(blobPoints(c, r, n: s.n, seed: UInt64(900 + idx * 13), jitter: s.jit, sx: s.sx, sy: s.sy, rot: s.rot), s.ten)
}

func drawBoulder(_ c: CGPoint, _ r: CGFloat, _ idx: Int, hot: Bool, shadow: Bool = true) {
    let path = boulderPath(c, r, idx)
    if hot { halo(c, r * 1.3, K.molten.alpha(0.55)) }
    let base = { radialFill(path, [K.basalt.lighter(0.28), K.basalt, K.basaltD, K.obs1], P(c.x - r * 0.35, c.y - r * 0.4), r * 1.6, [0, 0.35, 0.75, 1]) }
    if shadow { shadowed(r * 0.06, r * 0.1, Col(0.02, 0, 0.02, 0.55), base) } else { base() }
    var g = Rng(s: UInt64(700 + idx))
    clipped(path) {
        // strata
        for k in 0..<4 {
            let y = c.y - r * 0.6 + CGFloat(k) * r * 0.38 + g.r(-r * 0.08, r * 0.08)
            let pts = [P(c.x - r * 1.2, y + r * 0.2), P(c.x - r * 0.3, y + g.r(-r * 0.1, r * 0.1)), P(c.x + r * 0.5, y - r * 0.1), P(c.x + r * 1.2, y - r * 0.25)]
            let p = smoothOpen(pts)
            stroke(p, Col(0.03, 0.01, 0.03, 0.35), r * 0.03)
            stroke(moved(p, 0, r * 0.03), Col(0.9, 0.75, 0.75, 0.1), r * 0.015)
        }
        // facets lit from the top-left
        let fA = poly([P(c.x - r * 1.1, c.y - r * 0.2), P(c.x - r * 0.2, c.y - r * 0.35), P(c.x + r * 0.1, c.y - r * 1.2), P(c.x - r * 1.2, c.y - r * 1.2)])
        fill(fA, Col(1, 0.92, 0.9, 0.07))
        let fB = poly([P(c.x + r * 0.2, c.y + r * 0.1), P(c.x + r * 1.2, c.y - r * 0.2), P(c.x + r * 1.2, c.y + r * 1.2), P(c.x - r * 0.1, c.y + r * 1.2)])
        fill(fB, Col(0, 0, 0, 0.16))
        // speckles
        for _ in 0..<50 {
            let p = P(c.x + g.r(-r, r), c.y + g.r(-r, r))
            fill(circle(p, g.r(r * 0.008, r * 0.025)), g.next() > 0.5 ? Col(0.85, 0.75, 0.75, 0.2) : Col(0, 0, 0, 0.35))
        }
        // craters
        for k in 0..<3 {
            let a = g.r(0, .pi * 2), d = g.r(0.15, 0.55) * r
            let cc = polar(c, d, a), cr = r * g.r(0.1, 0.19) * (k == 0 ? 1.3 : 1)
            let crater = ellipse(R(cc.x - cr, cc.y - cr * 0.75, cr * 2, cr * 1.5))
            fill(moved(crater, -cr * 0.12, -cr * 0.14), Col(1, 0.9, 0.9, 0.12))
            fill(crater, K.basaltD.darker(0.35))
            edgeLight(crater, K.basalt.lighter(0.15).alpha(0.85), -cr * 0.35, -cr * 0.3, blur: cr * 0.15)
            if hot { edgeLight(crater, K.molten.alpha(0.55), cr * 0.3, cr * 0.3, blur: cr * 0.2) }
        }
        if hot {
            radialFill(path, [Col.clear, K.crimson.alpha(0.0), K.crimson.alpha(0.45)], P(c.x - r * 0.3, c.y - r * 0.3), r * 1.7, [0, 0.45, 1])
            var hg = Rng(s: UInt64(1200 + idx))
            for _ in 0..<4 {
                var p = P(c.x + hg.r(-r * 0.3, r * 0.3), c.y + hg.r(-r * 0.3, r * 0.3))
                var pts = [p]
                let a0 = hg.r(0, .pi * 2)
                for k in 0..<5 { let a = a0 + hg.r(-0.7, 0.7); p = polar(p, r * hg.r(0.15, 0.28), a); pts.append(p); _ = k }
                let cp = line(pts)
                softStroke(cp, K.molten.alpha(1), r * 0.12, blur: r * 0.1)
                stroke(cp, Col(hex: 0x8A1E10), r * 0.075)
                stroke(cp, K.molten, r * 0.05)
                stroke(cp, K.hot, r * 0.022)
            }
        }
    }
    edgeLight(path, Col(1, 0.94, 0.9, 0.24), r * 0.12, r * 0.12, blur: r * 0.07)
    edgeLight(path, (hot ? K.hot : K.molten2).alpha(hot ? 0.95 : 0.5), -r * 0.11, -r * 0.11, blur: r * 0.06)
    stroke(path, K.ink, max(1, r * 0.065))
}

func drawRockChip(_ c: CGPoint, _ r: CGFloat, _ idx: Int, hot: Bool = false) {
    var g = Rng(s: UInt64(1500 + idx))
    var pts: [CGPoint] = []
    let n = 5 + idx % 2
    for i in 0..<n { pts.append(polar(c, r * g.r(0.65, 1.0), CGFloat(i) / CGFloat(n) * .pi * 2 + g.r(-0.25, 0.25) + CGFloat(idx))) }
    let path = poly(pts)
    shadowed(r * 0.08, r * 0.12) { radialFill(path, [K.basalt.lighter(0.3), K.basalt, K.basaltD], P(c.x - r * 0.4, c.y - r * 0.4), r * 1.6) }
    clipped(path) { fill(poly([pts[0], pts[1], c]), Col(1, 0.95, 0.9, 0.12)); fill(poly([pts[2], pts[3], c]), Col(0, 0, 0, 0.2)) }
    edgeLight(path, (hot ? K.hot : K.molten2).alpha(0.6), -r * 0.15, -r * 0.15, blur: r * 0.08)
    stroke(path, K.ink, r * 0.12)
}

// MARK: - Volcano

/// Volcano in a 600 x 760 frame; crater mouth centred at (300, 46).
func drawVolcano(glowSky: Bool = true, streams: Bool = true) {
    var g = Rng(s: 51)
    let leftKeys = [P(0, 700), P(46, 606), P(96, 494), P(146, 378), P(190, 264), P(224, 166), P(246, 96), P(256, 52)]
    let rightKeys = [P(344, 52), P(355, 96), P(377, 166), P(411, 264), P(455, 378), P(505, 494), P(555, 606), P(600, 700)]
    var left = spline(leftKeys, 8), right = spline(rightKeys, 8)
    for i in 1..<(left.count - 2) { left[i] = P(left[i].x + g.r(-3, 3), left[i].y + g.r(-3, 3)) }
    for i in 1..<(right.count - 2) { right[i] = P(right[i].x + g.r(-3, 3), right[i].y + g.r(-3, 3)) }
    let rim = [P(262, 42), P(272, 37), P(284, 39), P(296, 35), P(308, 38), P(320, 36), P(332, 40), P(340, 44)]
    let outlinePts = left + rim + right
    let mountain = CGMutablePath()
    mountain.move(to: P(0, 761)); mountain.addLine(to: outlinePts[0])
    appendSmooth(mountain, outlinePts, 0.8)
    mountain.addLine(to: P(600, 761)); mountain.closeSubpath()
    let mPath: CGPath = mountain
    if glowSky {
        halo(P(300, 38), 120, K.molten.alpha(0.45))
        halo(P(300, 30), 50, K.hot.alpha(0.4))
    }
    linearFill(mPath, [Col(hex: 0x56444A), Col(hex: 0x3A2A30), K.obs2, K.obs1, K.obs0], P(0, 40), P(0, 760), [0, 0.15, 0.45, 0.8, 1])
    clipped(mPath) {
        // light from the top-left: lit left flank, shaded right flank
        ctx.drawLinearGradient(gradient([Col(1, 0.9, 0.9, 0.1), Col(1, 0.9, 0.9, 0), Col(0, 0, 0, 0), Col(0, 0, 0, 0.35)], [0, 0.4, 0.55, 1]), start: P(120, 0), end: P(560, 0), options: [])
        // gullies radiating from the crater
        for k in 0..<15 {
            let t = (CGFloat(k) + g.r(-0.3, 0.3)) / 14
            let startX = 262 + t * 76
            let endX = -40 + t * 680 + g.r(-20, 20)
            let midX = startX + (endX - startX) * 0.45 + g.r(-15, 15)
            let pts = [P(startX, 52), P(midX, 300 + g.r(-40, 40)), P(endX, 780)]
            let p = smoothOpen(pts)
            stroke(p, Col(0.02, 0, 0.02, 0.2), g.r(2, 6))
            stroke(moved(p, -3, 0), Col(0.85, 0.7, 0.75, 0.05), 1.5)
        }
        // strata ledges
        for k in 0..<14 {
            let y = 120 + CGFloat(k) * 44 + g.r(-10, 10)
            let half = 60 + (y - 46) * 0.4
            let x0 = 300 - half * g.r(0.2, 1.1), x1 = x0 + g.r(40, 120)
            let p = smoothOpen([P(x0, y), P((x0 + x1) / 2, y + g.r(-4, 6)), P(x1, y + g.r(4, 10))])
            stroke(p, Col(0.02, 0, 0.02, 0.4), 2.2)
            stroke(moved(p, 0, -1.6), Col(0.9, 0.75, 0.75, 0.08), 1.2)
        }
        // rubble speckles
        for _ in 0..<700 {
            let p = P(g.r(0, 600), g.r(40, 760))
            fill(circle(p, g.r(0.4, 1.6)), g.next() > 0.5 ? Col(0.8, 0.65, 0.65, 0.12) : Col(0, 0, 0, 0.3))
        }
        // warm lava glow on the lower slopes
        ctx.drawLinearGradient(gradient([K.molten.alpha(0), K.molten.alpha(0.12)]), start: P(0, 500), end: P(0, 760), options: [])
    }
    if streams {
        let paths: [[CGPoint]] = [
            [P(282, 52), P(262, 120), P(230, 210), P(206, 320), P(160, 430), P(132, 560), P(94, 680), P(72, 770)],
            [P(302, 54), P(306, 140), P(292, 240), P(312, 360), P(298, 480), P(320, 610), P(310, 770)],
            [P(322, 52), P(344, 130), P(374, 230), P(412, 340), P(444, 460), P(490, 590), P(520, 770)]
        ]
        for (k, keys) in paths.enumerated() {
            let pts = spline(keys, 12)
            let w0: CGFloat = 3, w1: CGFloat = k == 1 ? 20 : 16
            let rib = ribbon(pts) { t in w0 + (w1 - w0) * t + 2 * sin(t * 18 + CGFloat(k)) }
            clipped(mPath) {
                softFill(rib, K.molten.alpha(0.7), blur: 9)
                linearFill(rib, [Col(1, 0.97, 0.8), K.hot, K.molten2, K.molten, Col(hex: 0xA8261A)], P(0, 50), P(0, 760), [0, 0.05, 0.25, 0.6, 1])
                let core = ribbon(pts) { t in (w0 + (w1 - w0) * t) * 0.35 }
                fill(core, K.hot.alpha(0.75))
                // cooled crust flecks
                var cg = Rng(s: UInt64(60 + k))
                for i in stride(from: 14, to: pts.count - 2, by: 6) {
                    let p = pts[i]
                    if cg.next() > 0.45 { fill(blob(P(p.x + cg.r(-2, 2), p.y), cg.r(0.8, 2.0) * (0.4 + CGFloat(i) / CGFloat(pts.count)), n: 5, seed: UInt64(i + k * 100), jitter: 0.3, sx: 1.4, sy: 0.9), K.obs2.alpha(0.55)) }
                }
                edgeLight(rib, Col(1, 0.95, 0.8, 0.6), 2, 1, blur: 1)
            }
        }
    }
    // crater mouth
    let mouth = ellipse(R(258, 39.5, 84, 13))
    radialFill(mouth, [Col(1, 0.98, 0.85), K.hot, K.molten, Col(hex: 0xA8261A)], P(300, 47), 44, [0, 0.3, 0.7, 1])
    clipped(mouth) {
        fill(ellipse(R(250, 32, 100, 12)), K.obs1.alpha(0.55))
        for x in stride(from: 268.0, to: 336, by: 13) { fill(ellipse(R(x, 46, 7, 2)), Col(1, 1, 0.85, 0.7)) }
    }
    let lipFront = CGMutablePath(); lipFront.addArc(center: P(300, 46), radius: 42, startAngle: 0.15, endAngle: .pi - 0.15, clockwise: false)
    var sq = CGAffineTransform(translationX: 300, y: 46).scaledBy(x: 1, y: 6.5 / 42).translatedBy(x: -300, y: -46)
    let lip = lipFront.copy(using: &sq)!
    stroke(lip, Col(hex: 0x6A3A30), 3)
    stroke(moved(lip, 0, -1), K.hot.alpha(0.9), 1.2)
    softStroke(mouth, K.hot.alpha(0.9), 3, blur: 6)
    // rim lights: ash highlight on the left flank, molten rim on the right flank, warm outline
    edgeLight(mPath, K.ash.alpha(0.28), 4, 3, blur: 3)
    edgeLight(mPath, K.molten2.alpha(0.55), -5, 0, blur: 3)
    stroke(smoothOpen(outlinePts, 0.8), K.ink, 2.6)
}

// MARK: - Heroes

struct Look { let p: Col; let s: Col; let g: Col }
let looks: [String: Look] = [
    "ashRunner": Look(p: Col(0.78, 0.76, 0.80), s: Col(0.35, 0.33, 0.40), g: Col(1, 0.55, 0.2)),
    "emberScout": Look(p: Col(1, 0.58, 0.22), s: Col(0.55, 0.18, 0.08), g: Col(1, 0.85, 0.4)),
    "obsidianGhost": Look(p: Col(0.22, 0.18, 0.28), s: Col(0.6, 0.4, 0.95), g: Col(0.75, 0.55, 1)),
    "magmaTitan": Look(p: Col(0.8, 0.18, 0.14), s: Col(0.28, 0.05, 0.05), g: Col(1, 0.4, 0.15)),
    "crystalSpirit": Look(p: Col(0.45, 0.85, 0.95), s: Col(0.15, 0.4, 0.6), g: Col(0.7, 0.95, 1)),
    "phoenix": Look(p: Col(1, 0.8, 0.25), s: Col(0.9, 0.25, 0.1), g: Col(1, 0.6, 0.1))
]
let skinOrder = ["ashRunner", "emberScout", "obsidianGhost", "magmaTitan", "crystalSpirit", "phoenix"]

/// Thick limb: dark outline stroke, shaded body stroke, highlight stroke.
func limb(_ pts: [CGPoint], _ w: CGFloat, _ col: Col, ow: CGFloat) {
    let path = smoothOpen(pts)
    stroke(path, K.ink, w + ow * 2)
    stroke(path, col.darker(0.3), w)
    withT(-w * 0.16, -w * 0.08) { stroke(path, col, w * 0.64) }
    withT(-w * 0.26, -w * 0.14) { stroke(path, col.lighter(0.35).alpha(0.7), w * 0.2) }
}

func chibiEyes(_ c: CGPoint, _ dx: CGFloat, _ size: CGFloat, iris: Col = Col(hex: 0x2A1418), brows: Bool = false) {
    for side in [-1.0, 1.0] as [CGFloat] {
        let e = P(c.x + side * dx, c.y)
        let eye = ellipse(R(e.x - size * 0.42, e.y - size * 0.55, size * 0.84, size * 1.1))
        fill(eye, iris)
        fill(circle(P(e.x - size * 0.12, e.y - size * 0.2), size * 0.2), Col(1, 1, 1, 0.95))
        fill(circle(P(e.x + size * 0.14, e.y + size * 0.22), size * 0.09), Col(1, 1, 1, 0.7))
        if brows { stroke(line([P(e.x - side * size * 0.55, e.y - size * 0.62), P(e.x + side * size * 0.5, e.y - size * 1.0)]), K.ink, size * 0.28) }
    }
}

/// Draws a hero with the feet's ground contact at the origin; 78 pt tall. frame < 0 = heroic portrait pose.
func drawHero(_ skin: String, frame: Int, molten: Bool = false, shadow: Bool = true) {
    let L = looks[skin]!
    let ow: CGFloat = 1.1
    let heroic = frame < 0
    let table: [[CGFloat]] = [[-6, 0, 5, 3.5, 0, 1], [-5, 0, 4, 9, -2, 0.35], [-5, 3.5, 6, 0, 0, -1], [-4, 9, 5, 0, -2, -0.35]]
    let row: [CGFloat] = heroic ? [-8, 0, 8, 0, 0, 0] : table[frame % 4]
    let bob = row[4], swing = row[5]
    var torsoW: CGFloat = 9, waistW: CGFloat = 7, legW: CGFloat = 5.2, armW: CGFloat = 4.4, headR: CGFloat = 15.5
    switch skin {
    case "magmaTitan": torsoW = 13; waistW = 10.5; legW = 7; armW = 6; headR = 14.5
    case "crystalSpirit": torsoW = 7.5; waistW = 5; legW = 4.2; armW = 3.6; headR = 15
    case "obsidianGhost": legW = 4.6
    case "phoenix": torsoW = 8.5
    default: break
    }
    let sY = -43 + bob, hipY = -22 + bob, hy = -60 + bob
    let flap: CGFloat = heroic ? 2 : [1, 3, 1, 4][frame % 4]
    let p = L.p, s = L.s, gl = L.g

    if shadow { fill(ellipse(R(-16, -2.2, 32, 4.4)), Col(0.02, 0, 0.02, 0.35)) }
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)

    // ---- Back layer
    switch skin {
    case "ashRunner":
        let c = CGMutablePath()
        c.move(to: P(-7, sY))
        c.addCurve(to: P(-15 - flap, -7), control1: P(-13, sY + 8), control2: P(-17 - flap, -18))
        for q in [P(-10 - flap * 0.5, -10), P(-6, -5), P(-1, -9), P(4, -4.5), P(9 + flap * 0.5, -9), P(15 + flap, -6)] { c.addLine(to: q) }
        c.addCurve(to: P(7, sY), control1: P(17 + flap, -18), control2: P(13, sY + 8))
        c.closeSubpath()
        paint(c, s, ow: ow, rim: 0.6)
        clipped(c) { for x in [-8.0, 0, 8] as [CGFloat] { stroke(line([P(x * 0.4, sY + 4), P(x, -8)]), K.ink.alpha(0.3), 0.8) } }
    case "obsidianGhost":
        for (i, q) in [P(-14, sY - 4), P(14, sY - 6), P(-9, hy - 16), P(10, hy - 18), P(0, -8)].enumerated() {
            softFill(blob(q, 7 + CGFloat(i % 2) * 2, n: 6, seed: UInt64(30 + i), jitter: 0.3), s.alpha(0.35), blur: 4)
        }
        let tail = CGMutablePath()
        tail.move(to: P(-10, sY + 4)); tail.addCurve(to: P(-20 - flap, -4), control1: P(-18, -20), control2: P(-22, -10))
        tail.addCurve(to: P(-6, -14), control1: P(-14, -8), control2: P(-10, -12)); tail.closeSubpath()
        fill(tail, p.darker(0.3).alpha(0.8))
    case "phoenix":
        for side in [-1.0, 1.0] as [CGFloat] {
            let tipY = sY - 14 - flap * 1.2
            let w = CGMutablePath()
            w.move(to: P(side * 5, sY + 1))
            w.addCurve(to: P(side * 33, tipY), control1: P(side * 14, sY - 8), control2: P(side * 26, tipY - 4))
            let feathers: [CGPoint] = [P(side * 31, sY + 2 - flap * 0.4), P(side * 27, sY + 0), P(side * 28, sY + 14 - flap * 0.3), P(side * 22, sY + 10), P(side * 22, -8), P(side * 16, -14), P(side * 14, -4)]
            for (i, q) in feathers.enumerated() {
                if i % 2 == 0 { w.addQuadCurve(to: q, control: P(q.x + side * 4, q.y - 6)) } else { w.addLine(to: q) }
            }
            w.addCurve(to: P(side * 5, hipY), control1: P(side * 10, -8), control2: P(side * 6, -14))
            w.closeSubpath()
            let b = w.boundingBox
            linearFill(w, [p.lighter(0.25), p, s, Col(hex: 0x8A1410)], P(0, b.minY), P(side * 33, b.maxY), [0, 0.3, 0.75, 1])
            clipped(w) {
                for k in 0..<4 {
                    let y0 = sY - 4 + CGFloat(k) * 7
                    stroke(smoothOpen([P(side * 7, y0 + 4), P(side * 17, y0), P(side * 30, y0 - 5 + CGFloat(k) * 2)]), Col(0.5, 0.1, 0.02, 0.45), 0.9)
                }
            }
            edgeLight(w, K.hot.alpha(0.6), side * -2, 2, blur: 1.2)
            stroke(w, K.ink, ow)
        }
    default: break
    }

    // ---- Legs (planted leg first, the lifted one comes forward)
    let legCol: Col, bootCol: Col
    switch skin {
    case "ashRunner": legCol = s.darker(0.15); bootCol = Col(hex: 0x2E2426)
    case "emberScout": legCol = s; bootCol = Col(hex: 0x4A2A1A)
    case "obsidianGhost": legCol = p.darker(0.25); bootCol = p.darker(0.45)
    case "magmaTitan": legCol = s.lighter(0.08); bootCol = Col(hex: 0x3A2224)
    case "crystalSpirit": legCol = s.lighter(0.15); bootCol = s.lighter(0.35)
    default: legCol = s; bootCol = Col(hex: 0xC8551A)
    }
    let sides: [CGFloat] = row[1] > row[3] ? [1, -1] : [-1, 1]
    for side in sides {
        let fx = side < 0 ? row[0] : row[2], lift = side < 0 ? row[1] : row[3]
        let hip = P(side * waistW * 0.5, hipY)
        let ankle = P(fx * (lift > 4 ? 0.78 : 1), -2.6 - lift)
        let knee = P((hip.x + ankle.x) / 2 + side * 1.8, (hip.y + ankle.y) / 2 - lift * 0.3)
        limb([hip, knee, ankle], legW, legCol, ow: ow)
        let bw: CGFloat = skin == "magmaTitan" ? 1.3 : (skin == "crystalSpirit" ? 0.85 : 1)
        if skin == "crystalSpirit" {
            let f = poly([P(ankle.x - 3.4, ankle.y + 2.6), P(ankle.x - 1.5, ankle.y - 2.2), P(ankle.x + 2, ankle.y - 2.2), P(ankle.x + 3.6, ankle.y + 2.6)])
            paint(f, bootCol, ow: ow, rim: 0.3)
        } else if skin == "obsidianGhost" {
            let f = CGMutablePath(); f.move(to: P(ankle.x - 3.6, ankle.y + 2.6)); f.addQuadCurve(to: P(ankle.x + side * 5.5, ankle.y + 1.2), control: P(ankle.x - 3, ankle.y - 3.5)); f.addLine(to: P(ankle.x + 3, ankle.y + 2.6)); f.closeSubpath()
            paint(f, bootCol, ow: ow, rim: 0.3)
        } else {
            let boot = rr(R(ankle.x - 3.8 * bw, ankle.y - 1.8, 7.6 * bw, 4.4), 2.1)
            paint(boot, bootCol, ow: ow, rim: 0.5)
            if skin == "phoenix" { for k in [-1.0, 0, 1] as [CGFloat] { fill(circle(P(ankle.x + k * 2.6, ankle.y + 2.4), 0.8), K.ink) } }
            if skin == "magmaTitan" { stroke(line([P(ankle.x - 3, ankle.y - 0.3), P(ankle.x + 3, ankle.y - 0.3)]), gl.alpha(0.9), 0.6) }
        }
        if skin == "magmaTitan" { paint(circle(knee, 3.2), p, ow: ow, rim: 0.5) }
    }

    // ---- Torso
    let torso = CGMutablePath()
    torso.move(to: P(-torsoW, sY + 2))
    torso.addQuadCurve(to: P(0, sY - 1.5), control: P(-torsoW, sY - 1.5))
    torso.addQuadCurve(to: P(torsoW, sY + 2), control: P(torsoW, sY - 1.5))
    torso.addLine(to: P(waistW, hipY + 2))
    torso.addQuadCurve(to: P(-waistW, hipY + 2), control: P(0, hipY + 4.5))
    torso.closeSubpath()
    switch skin {
    case "obsidianGhost":
        let robe = CGMutablePath()
        robe.move(to: P(-torsoW, sY + 2))
        robe.addQuadCurve(to: P(torsoW, sY + 2), control: P(0, sY - 4))
        robe.addCurve(to: P(13 + flap * 0.5, -9), control1: P(torsoW + 2, -24), control2: P(12, -16))
        for q in [P(8, -13), P(5, -7), P(1, -12), P(-3, -6.5), P(-7, -12.5), P(-12 - flap * 0.5, -8)] { robe.addLine(to: q) }
        robe.addCurve(to: P(-torsoW, sY + 2), control1: P(-12, -16), control2: P(-torsoW - 2, -24))
        robe.closeSubpath()
        paint(robe, p, ow: ow, rim: 0.35, rimCol: s)
        clipped(robe) {
            stroke(line([P(-13, -12), P(-7, -14.5), P(-3, -8.5), P(1, -14), P(5, -9), P(8, -15), P(14, -11)]), s.alpha(0.8), 1.2)
            softStroke(line([P(-13, -12), P(-7, -14.5), P(-3, -8.5), P(1, -14), P(5, -9), P(8, -15), P(14, -11)]), gl.alpha(0.8), 1.5, blur: 2)
            stroke(line([P(0, sY + 2), P(0, -14)]), K.ink.alpha(0.4), 0.8)
        }
    case "magmaTitan":
        paint(torso, p, ow: ow, rim: 0.6)
        clipped(torso) {
            fill(rectPath(R(-waistW - 2, hipY - 2, waistW * 2 + 4, 5)), s.lighter(0.1))
            stroke(line([P(-waistW - 2, hipY - 2), P(waistW + 2, hipY - 2)]), K.ink, 0.8)
            let cracks = [[P(-8, sY + 3), P(-5, sY + 8), P(-7, sY + 13)], [P(6, sY + 2), P(3, sY + 7), P(6, sY + 12), P(4, sY + 17)], [P(-2, sY + 14), P(1, sY + 18)]]
            for c in cracks { softStroke(line(c), gl.alpha(1), 1.4, blur: 1.8); stroke(line(c), K.hot, 0.6) }
            halo(P(0, sY + 9), 5, gl.alpha(0.9))
            fill(poly([P(0, sY + 5.5), P(3, sY + 9), P(0, sY + 12.5), P(-3, sY + 9)]), K.hot)
            stroke(poly([P(0, sY + 5.5), P(3, sY + 9), P(0, sY + 12.5), P(-3, sY + 9)]), K.ink, 0.6)
        }
    case "crystalSpirit":
        let t = poly([P(-torsoW, sY + 1), P(0, sY - 1.5), P(torsoW, sY + 1), P(waistW + 1, hipY - 2), P(0, hipY + 3.5), P(-waistW - 1, hipY - 2)])
        paint(t, p, ow: ow, rim: 0.3, rimCol: gl)
        clipped(t) {
            let c = P(-1, sY + 9)
            fill(poly([P(-torsoW, sY + 1), P(0, sY - 1.5), c]), Col(1, 1, 1, 0.35))
            fill(poly([P(torsoW, sY + 1), P(waistW + 1, hipY - 2), c]), s.alpha(0.45))
            fill(poly([P(0, hipY + 3.5), P(waistW + 1, hipY - 2), c]), s.darker(0.2).alpha(0.5))
            fill(poly([P(-waistW - 1, hipY - 2), P(-torsoW, sY + 1), c]), Col(1, 1, 1, 0.12))
            halo(c, 4, gl.alpha(0.9))
        }
        stroke(t, K.ink, ow)
    case "phoenix":
        paint(torso, p, ow: ow, rim: 0.5)
        clipped(torso) {
            fill(ellipse(R(-5, sY + 4, 10, 16)), Col(1, 0.93, 0.7, 0.7))
            for k in 0..<4 {
                let y = sY + 4 + CGFloat(k) * 4.5
                stroke(line([P(-5, y), P(0, y + 2.5), P(5, y)]), s.alpha(0.55), 0.8)
            }
            fill(rectPath(R(-waistW - 2, hipY - 1.5, waistW * 2 + 4, 3.5)), s.darker(0.25))
        }
    case "emberScout":
        paint(torso, p, ow: ow, rim: 0.4)
        clipped(torso) {
            fill(poly([P(-5, sY - 1), P(0, sY + 6), P(5, sY - 1), P(5, sY - 3), P(-5, sY - 3)]), s)
            stroke(line([P(0, sY + 6), P(0, hipY + 1)]), p.darker(0.4), 0.8)
            fill(rectPath(R(-waistW - 2, hipY - 2, waistW * 2 + 4, 3.6)), Col(hex: 0x4A2A1A))
            fill(rr(R(-1.8, hipY - 2.3, 3.6, 4.2), 0.8), K.hot)
            fill(rr(R(-6, sY + 8, 4, 4), 1), p.darker(0.25))
        }
    default: // ashRunner
        paint(torso, p.darker(0.18), ow: ow, rim: 0.45)
        clipped(torso) {
            fill(rectPath(R(-waistW - 2, hipY - 2, waistW * 2 + 4, 3.4)), Col(hex: 0x2E2426))
            fill(rr(R(-1.8, hipY - 2.2, 3.6, 3.8), 0.8), gl)
            stroke(line([P(-torsoW, sY + 3), P(torsoW * 0.6, hipY - 2)]), s.alpha(0.7), 2.2)
        }
    }

    // ---- Arms
    let armCol: Col, handCol: Col
    switch skin {
    case "ashRunner": armCol = p.darker(0.1); handCol = Col(hex: 0x3A3036)
    case "emberScout": armCol = p; handCol = Col(hex: 0xF2C29A)
    case "obsidianGhost": armCol = p; handCol = s.lighter(0.25)
    case "magmaTitan": armCol = p.darker(0.15); handCol = s.lighter(0.18)
    case "crystalSpirit": armCol = p; handCol = gl
    default: armCol = p; handCol = Col(hex: 0xFFB040)
    }
    func drawArm(_ pts: [CGPoint]) {
        if skin == "obsidianGhost" {
            limb(pts, armW, armCol, ow: ow)
            let h = pts[2], e = pts[1]
            let dx = h.x - e.x, dy = h.y - e.y, l = max(hypot(dx, dy), 0.01)
            let nx = -dy / l, ny = dx / l
            let cuff = poly([P(h.x - dx / l * 3.5 + nx * 2.2, h.y - dy / l * 3.5 + ny * 2.2), P(h.x + nx * 4, h.y + ny * 4), P(h.x - nx * 4, h.y - ny * 4), P(h.x - dx / l * 3.5 - nx * 2.2, h.y - dy / l * 3.5 - ny * 2.2)])
            paint(cuff, p, ow: ow, rim: 0.3, rimCol: s)
            halo(P(h.x + dx / l * 1.5, h.y + dy / l * 1.5), 4, gl.alpha(0.7))
            fill(circle(P(h.x + dx / l * 1.5, h.y + dy / l * 1.5), 1.8), handCol)
            return
        }
        limb(pts, armW, armCol, ow: ow)
        let h = pts[2]
        if skin == "crystalSpirit" {
            let d = poly([P(h.x, h.y - 2.8), P(h.x + 2.2, h.y), P(h.x, h.y + 2.8), P(h.x - 2.2, h.y)])
            halo(h, 4, gl.alpha(0.7)); paint(d, handCol, ow: ow * 0.8, rim: 0)
        } else {
            paint(circle(h, armW * 0.62), handCol, ow: ow, rim: 0.4)
        }
    }
    func armPts(_ side: CGFloat) -> [CGPoint] {
        let sh = P(side * (torsoW - 1.6), sY + 2.6)
        if heroic {
            if side < 0 { return [sh, P(-torsoW - 4, sY + 9), P(-torsoW - 3, sY + 16)] }
            return [sh, P(torsoW + 7, sY - 2), P(torsoW + 9, sY - 11)]
        }
        let t = side < 0 ? (swing + 1) / 2 : (1 - swing) / 2
        let back = P(side * (torsoW + 4.5), sY + 15.5), fwd = P(side * 3.8, sY + 11)
        let hand = mixP(back, fwd, t)
        let elbow = P((sh.x + hand.x) / 2 + side * (2.2 + t * 1.6), (sh.y + hand.y) / 2 + 0.5)
        return [sh, elbow, hand]
    }
    let armOrder: [CGFloat] = swing >= 0 ? [1, -1] : [-1, 1]
    for side in armOrder where !(heroic && side > 0) { drawArm(armPts(side)) }
    if skin == "magmaTitan" {
        for side in [-1.0, 1.0] as [CGFloat] {
            let pd = ellipse(R(side * (torsoW + 0.5) - 6.5, sY - 3.5, 13, 10))
            paint(pd, p, ow: ow, rim: 0.6)
            clipped(pd) { let c = line([P(side * (torsoW - 3), sY - 2), P(side * (torsoW + 1), sY + 2), P(side * (torsoW + 4), sY + 1)]); softStroke(c, gl.alpha(1), 1.2, blur: 1.5); stroke(c, K.hot, 0.5) }
        }
    }
    if skin == "emberScout" {
        // lantern on the right hip
        let lx = waistW + 2.6, ly = hipY + 3
        stroke(line([P(lx - 2, hipY - 1), P(lx, ly - 4)]), K.ink, 0.9)
        halo(P(lx, ly + 1), 9, gl.alpha(0.8))
        let body = rr(R(lx - 2.6, ly - 3, 5.2, 7.5), 1.6)
        radialFill(body, [Col(1, 1, 0.85), gl, K.molten], P(lx, ly + 1), 5)
        stroke(body, K.ink, ow * 0.9)
        fill(rr(R(lx - 3.2, ly - 4.4, 6.4, 2), 0.8), Col(hex: 0x3A2420)); fill(rr(R(lx - 3.2, ly + 4, 6.4, 1.6), 0.6), Col(hex: 0x3A2420))
        drawFlame(P(lx, ly + 3), 2.6, 4.5)
    }

    // ---- Head
    let hc = P(0, hy)
    switch skin {
    case "ashRunner":
        let hood = smoothClosed([P(-17, hy + 4), P(-16.5, hy - 7), P(-11, hy - 15.5), P(-2, hy - 18.5), P(7, hy - 18), P(14, hy - 21.5 - flap * 0.4), P(15.5, hy - 12), P(17, hy + 2), P(14, hy + 11), P(0, hy + 14), P(-13, hy + 11)], 0.9)
        paint(hood, p, ow: ow, rim: 0.5)
        clipped(hood) {
            stroke(smoothOpen([P(-12, hy - 10), P(-4, hy - 16), P(8, hy - 15)]), p.darker(0.35).alpha(0.6), 0.9)
            stroke(smoothOpen([P(12, hy - 14), P(15, hy - 2)]), p.darker(0.35).alpha(0.5), 0.8)
        }
        let face = ellipse(R(-10.5, hy - 8, 21, 19))
        radialFill(face, [K.obs2, K.obs1, K.obs0], P(0, hy + 2), 11)
        edgeLight(face, Col(0, 0, 0, 0.6), 0, 3, blur: 1.5)
        stroke(face, K.ink, ow * 0.8)
        let visor = rr(R(-9.5, hy - 2.2, 19, 5.4), 2.7)
        halo(P(0, hy + 0.5), 14, gl.alpha(0.6))
        linearFill(visor, [Col(1, 0.95, 0.7), gl, K.molten], P(0, hy - 2.2), P(0, hy + 3.2))
        stroke(visor, K.ink, ow * 0.7)
        fill(rr(R(-7, hy - 1.4, 7, 1.2), 0.6), Col(1, 1, 1, 0.8))
        // scarf wrap
        let scarf = smoothClosed([P(-9, hy + 10), P(0, hy + 13), P(9, hy + 10), P(8, hy + 15), P(0, hy + 17), P(-8, hy + 15)], 0.8)
        paint(scarf, s.lighter(0.1), ow: ow, rim: 0.4)
    case "emberScout":
        let head = circle(hc, headR)
        paint(head, Col(hex: 0xF2C29A), ow: ow, rim: 0.45, hi: 0.3)
        let hair = CGMutablePath()
        hair.move(to: P(-headR - 0.8, hy + 3))
        hair.addCurve(to: P(0, hy - headR - 2.5), control1: P(-headR - 1.5, hy - 9), control2: P(-9, hy - headR - 2.5))
        hair.addCurve(to: P(headR + 0.8, hy + 3), control1: P(9, hy - headR - 2.5), control2: P(headR + 1.5, hy - 9))
        for q in [P(12, hy - 3), P(9, hy - 1.5), P(7, hy - 6), P(3.5, hy - 2.5), P(0.5, hy - 6.5), P(-3, hy - 2.5), P(-6.5, hy - 6), P(-9, hy - 1.5), P(-12, hy - 3)] { hair.addLine(to: q) }
        hair.closeSubpath()
        paint(hair, Col(hex: 0x8A3414), ow: ow, rim: 0.4)
        // goggles strap and lenses
        stroke(smoothOpen([P(-headR + 0.5, hy - 7), P(0, hy - 10.5), P(headR - 0.5, hy - 7)]), K.ink, 2.6)
        stroke(smoothOpen([P(-headR + 0.5, hy - 7), P(0, hy - 10.5), P(headR - 0.5, hy - 7)]), Col(hex: 0x4A2A1A), 1.6)
        for side in [-1.0, 1.0] as [CGFloat] {
            let lc = P(side * 5.5, hy - 9.5)
            paint(circle(lc, 4), Col(hex: 0x6A5A5A), ow: ow, rim: 0.3)
            radialFill(circle(lc, 2.6), [Col(1, 1, 0.9), gl, K.molten], P(lc.x - 0.8, lc.y - 0.8), 3.2)
            fill(circle(P(lc.x - 1, lc.y - 1), 0.8), Col(1, 1, 1, 0.9))
        }
        chibiEyes(P(0, hy + 2.8), 5.4, 4.6)
        fill(ellipse(R(-12, hy + 6, 4.5, 2.4)), Col(1, 0.45, 0.35, 0.4)); fill(ellipse(R(7.5, hy + 6, 4.5, 2.4)), Col(1, 0.45, 0.35, 0.4))
        let m = CGMutablePath(); m.move(to: P(-2.2, hy + 8.5)); m.addQuadCurve(to: P(2.2, hy + 8.5), control: P(0, hy + 10.5))
        stroke(m, Col(hex: 0x6A2A1E), 0.9)
        fill(circle(P(-9, hy + 6.5), 0.5), Col(hex: 0xC8784A)); fill(circle(P(-10.2, hy + 5.6), 0.4), Col(hex: 0xC8784A))
    case "obsidianGhost":
        let hood = smoothClosed([P(-16, hy + 6), P(-16, hy - 6), P(-12, hy - 14), P(-9, hy - 22 - flap * 0.5), P(-5, hy - 16), P(0, hy - 18.5), P(5, hy - 17), P(10, hy - 24 - flap * 0.6), P(12.5, hy - 13), P(16, hy - 5), P(16.5, hy + 6), P(12, hy + 13), P(0, hy + 15), P(-12, hy + 13)], 0.85)
        paint(hood, p, ow: ow, rim: 0.4, rimCol: s)
        clipped(hood) { stroke(smoothOpen([P(-12, hy - 10), P(0, hy - 14), P(12, hy - 10)]), s.alpha(0.5), 0.8) }
        let face = ellipse(R(-11, hy - 8, 22, 20))
        radialFill(face, [Col(hex: 0x1A1028), K.obs0], P(0, hy + 2), 12)
        stroke(face, K.ink, ow * 0.8)
        halo(P(0, hy + 1), 14, gl.alpha(0.45))
        for side in [-1.0, 1.0] as [CGFloat] {
            let e = poly([P(side * 1.6, hy - 0.2), P(side * 8, hy - 2.8), P(side * 7.4, hy + 2.6), P(side * 2.4, hy + 2.2)])
            halo(P(side * 5, hy), 6, gl.alpha(0.9))
            fill(smoothClosed([P(side * 1.6, hy - 0.2), P(side * 8, hy - 2.8), P(side * 7.4, hy + 2.6), P(side * 2.4, hy + 2.2)], 0.4), Col(0.95, 0.9, 1))
            stroke(e, gl.alpha(0.6), 0.6)
        }
        for k in 0..<3 { fill(circle(P(CGFloat(k - 1) * 9, hy - 26 - CGFloat(k % 2) * 3), 1 + CGFloat(k % 2) * 0.6), s.alpha(0.6)) }
    case "magmaTitan":
        for side in [-1.0, 1.0] as [CGFloat] {
            let horn = CGMutablePath()
            horn.move(to: P(side * 8, hy - 10))
            horn.addCurve(to: P(side * 19, hy - 23), control1: P(side * 12, hy - 17), control2: P(side * 16, hy - 21))
            horn.addCurve(to: P(side * 14, hy - 3), control1: P(side * 20, hy - 15), control2: P(side * 18, hy - 7))
            horn.closeSubpath()
            paint(horn, Col(hex: 0x8A7470), ow: ow, rim: 0.6)
            clipped(horn) { for k in 0..<3 { stroke(line([P(side * (11 + CGFloat(k) * 3), hy - 4 - CGFloat(k) * 5), P(side * (15 + CGFloat(k) * 3), hy - 8 - CGFloat(k) * 5)]), K.ink.alpha(0.35), 0.6) } }
        }
        let helm = smoothClosed([P(-14, hy - 4), P(-11, hy - 13), P(0, hy - 16), P(11, hy - 13), P(14, hy - 4), P(13.5, hy + 8), P(6, hy + 14), P(-6, hy + 14), P(-13.5, hy + 8)], 0.8)
        paint(helm, s.lighter(0.12), ow: ow, rim: 0.6)
        clipped(helm) {
            fill(poly([P(-2.5, hy - 17), P(2.5, hy - 17), P(1.6, hy - 3), P(-1.6, hy - 3)]), p)
            let cr = line([P(-9, hy + 6), P(-6, hy + 9), P(-8, hy + 13)])
            softStroke(cr, gl.alpha(1), 1.3, blur: 1.6); stroke(cr, K.hot, 0.5)
            let cr2 = line([P(10, hy - 8), P(7, hy - 5), P(9, hy - 1)])
            softStroke(cr2, gl.alpha(1), 1.3, blur: 1.6); stroke(cr2, K.hot, 0.5)
        }
        let slit = rr(R(-10, hy - 1.5, 20, 4.2), 2)
        halo(P(0, hy + 0.5), 13, gl.alpha(0.7))
        fill(slit, K.obs0)
        linearFill(rr(R(-9, hy - 0.8, 18, 2.8), 1.4), [K.hot, gl], P(0, hy - 1), P(0, hy + 2))
        stroke(slit, K.ink, ow * 0.7)
        fill(rr(R(-5, hy + 6.5, 10, 4), 1.4), K.obs1); for k in 0..<3 { stroke(line([P(-3 + CGFloat(k) * 3, hy + 7.2), P(-3 + CGFloat(k) * 3, hy + 9.8)]), gl.alpha(0.7), 0.6) }
    case "crystalSpirit":
        let spikes: [[CGPoint]] = [[P(-8, hy - 9), P(-12, hy - 24), P(-3, hy - 13)], [P(-3, hy - 13), P(1, hy - 31 - flap * 0.3), P(5, hy - 13)], [P(4, hy - 12), P(12, hy - 25), P(10, hy - 7)]]
        for sp in spikes { let path = poly(sp); paint(path, p.lighter(0.1), ow: ow, rim: 0.3, rimCol: gl); clipped(path) { fill(poly([sp[0], sp[1], mixP(sp[0], sp[2], 0.5)]), Col(1, 1, 1, 0.35)) } ; stroke(path, K.ink, ow) }
        let pts = [P(0, hy - 17), P(12, hy - 10), P(13.5, hy + 4), P(0, hy + 15), P(-13.5, hy + 4), P(-12, hy - 10)]
        let head = poly(pts)
        paint(head, p, ow: 0, rim: 0.35, rimCol: gl)
        let c = P(-1.5, hy - 2)
        let tones: [Col] = [Col(1, 1, 1, 0.38), s.alpha(0.25), s.alpha(0.45), s.darker(0.2).alpha(0.4), Col(1, 1, 1, 0.12), Col(1, 1, 1, 0.28)]
        for i in 0..<6 { fill(poly([pts[i], pts[(i + 1) % 6], c]), tones[i]) }
        for i in 0..<6 { stroke(line([pts[i], c]), Col(1, 1, 1, 0.25), 0.5) }
        stroke(head, K.ink, ow)
        for side in [-1.0, 1.0] as [CGFloat] {
            halo(P(side * 5, hy + 2), 6, gl.alpha(0.9))
            fill(ellipse(R(side * 5 - 1.8, hy - 0.6, 3.6, 5.2)), Col(0.95, 1, 1))
            stroke(ellipse(R(side * 5 - 1.8, hy - 0.6, 3.6, 5.2)), s.darker(0.3), 0.6)
        }
        for (i, q) in [P(-19, sY - 6), P(19, sY - 2)].enumerated() {
            let fy = q.y + (CGFloat(i) - 0.5) * flap
            let d = poly([P(q.x, fy - 4), P(q.x + 2.4, fy), P(q.x, fy + 4), P(q.x - 2.4, fy)])
            halo(P(q.x, fy), 6, gl.alpha(0.7)); paint(d, p.lighter(0.2), ow: ow * 0.8, rim: 0)
        }
    default: // phoenix
        let crest: [(CGPoint, CGFloat, CGFloat, CGFloat)] = [(P(-5, hy - 11), 7, 17, -5), (P(1, hy - 13), 8, 22, 1), (P(6.5, hy - 11), 7, 17, 6)]
        for (b, w, h, lean) in crest {
            let f = flamePath(b, w, h + flap * 0.6, lean: lean)
            halo(P(b.x + lean * 0.5, b.y - h * 0.5), h * 0.7, gl.alpha(0.45))
            linearFill(f, [p, K.molten2, K.crimson], P(b.x, b.y), P(b.x, b.y - h), [0, 0.5, 1])
            stroke(f, K.ink, ow)
            fill(flamePath(P(b.x, b.y - 1), w * 0.45, h * 0.55, lean: lean * 0.5), K.hot.alpha(0.9))
        }
        let head = circle(hc, headR)
        paint(head, p, ow: ow, rim: 0.5)
        clipped(head) {
            fill(ellipse(R(-10, hy - 2, 20, 16)), Col(1, 0.95, 0.75, 0.65))
            for side in [-1.0, 1.0] as [CGFloat] { fill(poly([P(side * 16, hy + 2), P(side * 10, hy + 6), P(side * 16, hy + 8)]), s.alpha(0.7)) }
        }
        chibiEyes(P(0, hy - 0.5), 5.6, 4.6, brows: true)
        let beak = smoothClosed([P(-3.2, hy + 4.2), P(3.2, hy + 4.2), P(0, hy + 10)], 0.4)
        paint(beak, Col(hex: 0xFF8A2A), ow: ow * 0.8, rim: 0)
        stroke(line([P(-2.4, hy + 6), P(2.4, hy + 6)]), K.ink.alpha(0.5), 0.5)
    }

    // ---- Heroic raised arm in front of everything
    if heroic {
        drawArm(armPts(1))
        let h = armPts(1)[2]
        halo(P(h.x, h.y - 5), 9, gl.alpha(0.8))
        drawFlame(P(h.x, h.y - 2.5), 4, 9, lean: 0.6)
    }

    if molten {
        let b = R(-40, -100, 80, 104)
        ctx.setBlendMode(.sourceAtop)
        ctx.drawLinearGradient(gradient([K.hot.alpha(0.7), K.molten.alpha(0.7), K.crimson.alpha(0.65)]), start: P(0, b.minY + 10), end: P(0, b.maxY), options: [])
        ctx.setBlendMode(.normal)
    }
    ctx.endTransparencyLayer()
}

// MARK: - Skies

func ridge(_ baseY: CGFloat, amp: CGFloat, seed: UInt64, w: CGFloat, h: CGFloat, cols: [Col], rimCol: Col) {
    var g = Rng(s: seed)
    var pts: [CGPoint] = [P(-10, baseY)]
    var x: CGFloat = -10
    while x < w + 10 { x += g.r(18, 40); pts.append(P(x, baseY - g.r(amp * 0.2, amp))) }
    let edge = smoothOpen(pts, 0.5)
    let path = CGMutablePath(); path.addPath(edge); path.addLine(to: P(w + 20, h + 10)); path.addLine(to: P(-20, h + 10)); path.closeSubpath()
    linearFill(path, cols, P(0, baseY - amp), P(0, baseY + 120))
    softStroke(edge, rimCol, 2, blur: 3)
    stroke(edge, rimCol.alpha(rimCol.a * 0.5), 0.7)
}

func ashCloud(_ c: CGPoint, _ r: CGFloat, seed: UInt64, dark: Col, lit: Col, alpha: CGFloat) {
    var g = Rng(s: seed)
    let path = CGMutablePath()
    path.addPath(rr(R(c.x - r * 2.0, c.y - r * 0.45, r * 4.0, r * 0.75), r * 0.37))
    for i in 0..<7 {
        let t = CGFloat(i) / 6
        let x = c.x - r * 1.6 + t * r * 3.2 + g.r(-r * 0.12, r * 0.12)
        let pr = r * g.r(0.5, 0.78) * (1 - abs(t - 0.5) * 0.75)
        path.addPath(circle(P(x, c.y - pr * 0.45 + g.r(-r * 0.06, r * 0.06)), pr))
    }
    let b = path.boundingBox
    let body = dark.lighter(0.12)
    linearFill(path, [body.lighter(0.12).alpha(alpha), body.alpha(alpha), dark.mix(lit, 0.35).alpha(alpha)], P(0, b.minY), P(0, b.maxY), [0, 0.5, 1])
    edgeLight(path, lit.alpha(alpha * 0.55), 0, -r * 0.14, blur: r * 0.14)
    edgeLight(path, Col(1, 0.9, 0.95, alpha * 0.1), r * 0.06, r * 0.18, blur: r * 0.12)
}

func drawSkyScene(_ mood: String, w: CGFloat, h: CGFloat) {
    var stops: [Col]
    var smoke = Col(hex: 0x4A2438), cloudDark = Col(hex: 0x3A1C2A), cloudLit = K.molten, horizon = K.molten.alpha(0.45)
    var starCount = 170
    var ridgeRim = K.molten.alpha(0.5)
    var ridgeCols = [[Col(hex: 0x2E1622), Col(hex: 0x1C0E16)], [Col(hex: 0x22101A), Col(hex: 0x140A10)], [Col(hex: 0x170A10), K.obs0]]
    switch mood {
    case "fury":
        stops = [Col(hex: 0x12040A), Col(hex: 0x3A0A16), Col(hex: 0x7A1A1A), Col(hex: 0xC2401E)]
        smoke = Col(hex: 0x5A1418); cloudDark = Col(hex: 0x2A080E); cloudLit = Col(hex: 0xFF4A1A); horizon = Col(hex: 0xFF3A1A, 0.6); starCount = 60
        ridgeRim = Col(hex: 0xFF4A1A, 0.75)
        ridgeCols = [[Col(hex: 0x3A0E14), Col(hex: 0x220810)], [Col(hex: 0x2A0A10), Col(hex: 0x16060A)], [Col(hex: 0x1A060A), K.obs0]]
    case "ashrain":
        stops = [Col(hex: 0x14101A), Col(hex: 0x2E2632), Col(hex: 0x54485A), Col(hex: 0x86768A)]
        smoke = Col(hex: 0x6A5A6E); cloudDark = Col(hex: 0x3A3040); cloudLit = K.ash; horizon = K.ash.alpha(0.3); starCount = 25
        ridgeRim = K.ash.alpha(0.45)
        ridgeCols = [[Col(hex: 0x3E3444), Col(hex: 0x2A2230)], [Col(hex: 0x2A2230), Col(hex: 0x1A141E)], [Col(hex: 0x1A141E), K.obs0]]
    case "embershower":
        stops = [Col(hex: 0x0E0610), Col(hex: 0x2A1218), Col(hex: 0x6A3218), Col(hex: 0xC8782A)]
        smoke = Col(hex: 0x5A3020); cloudDark = Col(hex: 0x2E1614); cloudLit = K.hot; horizon = K.hot.alpha(0.45)
        ridgeRim = K.hot.alpha(0.6)
        ridgeCols = [[Col(hex: 0x3A1E18), Col(hex: 0x24120E)], [Col(hex: 0x2A140E), Col(hex: 0x180A0A)], [Col(hex: 0x1A0A0A), K.obs0]]
    default:
        stops = [K.obs0, K.obs1, K.obs2, Col(hex: 0x6A2A22)]
    }
    linearFill(rectPath(R(0, 0, w, h)), stops, P(0, 0), P(0, h * 0.72), [0, 0.35, 0.72, 1])
    var g = Rng(s: UInt64(mood.count * 31 + 7))
    for _ in 0..<starCount {
        let p = P(g.r(0, w), g.r(0, h * 0.55)), rad = g.r(0.3, 1.15)
        let a = g.r(0.3, 0.95) * max(0, 1 - p.y / (h * 0.6))
        if rad > 1.0 { glow(p, rad * 6, Col(1, 0.85, 0.75, a * 0.5)) }
        fill(circle(p, rad), Col(1, 0.94, 0.9, a))
    }
    // nebula smoke
    blurredLayer(26) {
        for i in 0..<8 {
            let c = P(g.r(-60, w + 60), g.r(40, h * 0.6))
            fill(blob(c, g.r(50, 110), n: 8, seed: UInt64(20 + i), jitter: 0.3, sx: 1.8, sy: 0.5), smoke.alpha(g.r(0.3, 0.55)))
        }
    }
    glow(P(w * 0.5, h * 0.76), w * 1.0, horizon)
    // distant ash clouds: far ones softer, nearer ones crisper and lit from below by lava glow
    blurredLayer(7) {
        for i in 0..<5 {
            let c = P(g.r(-40, w + 40), h * (0.1 + CGFloat(i) * 0.075) + g.r(-20, 20))
            ashCloud(c, g.r(36, 52), seed: UInt64(80 + i), dark: cloudDark, lit: cloudLit, alpha: 0.4 + CGFloat(i) * 0.05)
        }
    }
    blurredLayer(3) {
        for i in 0..<5 {
            let c = P(CGFloat(i % 2 == 0 ? 1 : 0) * w * 0.7 + g.r(-40, 60), h * (0.44 + CGFloat(i) * 0.05) + g.r(-15, 15))
            ashCloud(c, g.r(44, 64), seed: UInt64(90 + i), dark: cloudDark, lit: cloudLit, alpha: 0.7 + CGFloat(i) * 0.05)
        }
    }
    if mood == "fury" {
        for k in 0..<2 {
            var p = P(k == 0 ? w * 0.22 : w * 0.78, h * 0.18)
            var pts = [p]
            for _ in 0..<7 { p = P(p.x + g.r(-14, 14), p.y + g.r(14, 26)); pts.append(p) }
            softStroke(line(pts), Col(1, 0.6, 0.8, 0.8), 3, blur: 6)
            stroke(line(pts), Col(1, 0.92, 0.95, 0.9), 1.1)
        }
        for _ in 0..<70 { let p = P(g.r(0, w), g.r(h * 0.3, h * 0.8)); spark(p, g.r(0.5, 1.2), Col(1, 0.4, 0.15, g.r(0.4, 0.9))) }
    }
    // ridges in the bottom third
    ridge(h * 0.69, amp: 70, seed: 3, w: w, h: h, cols: ridgeCols[0], rimCol: ridgeRim.alpha(ridgeRim.a * 0.6))
    ridge(h * 0.75, amp: 55, seed: 4, w: w, h: h, cols: ridgeCols[1], rimCol: ridgeRim.alpha(ridgeRim.a * 0.8))
    ridge(h * 0.81, amp: 40, seed: 5, w: w, h: h, cols: ridgeCols[2], rimCol: ridgeRim)
    switch mood {
    case "ashrain":
        for i in 0..<5 { softFill(rectPath(R(-50, h * (0.2 + CGFloat(i) * 0.15), w + 100, 60)), K.ash.alpha(0.08), blur: 30) }
        ctx.saveGState()
        for _ in 0..<320 {
            let x = g.r(-40, w), y = g.r(-20, h * 0.95), len = g.r(10, 28)
            ctx.setStrokeColor(Col(0.85, 0.78, 0.85, g.r(0.12, 0.35)).cg); ctx.setLineWidth(g.r(0.5, 1.2))
            ctx.move(to: P(x, y)); ctx.addLine(to: P(x + len * 0.35, y + len)); ctx.strokePath()
        }
        ctx.restoreGState()
        for _ in 0..<40 { let p = P(g.r(0, w), g.r(0, h * 0.8)); fill(blob(p, g.r(0.8, 2), n: 5, seed: UInt64(g.r(1, 999)), jitter: 0.3, t: 0.3), Col(0.2, 0.16, 0.22, 0.7)) }
    case "embershower":
        glow(P(w * 0.5, h * 0.05), w * 0.8, K.hot.alpha(0.25))
        for _ in 0..<150 {
            let p = P(g.r(0, w), g.r(0, h * 0.85)), r = g.r(0.4, 1.4)
            spark(p, r, Col(1, g.r(0.6, 0.9), 0.3, g.r(0.4, 1)))
        }
        for _ in 0..<14 { drawEmber(P(g.r(10, w - 10), g.r(30, h * 0.7)), g.r(2, 3.6), glowAmount: 0.8) }
    default: break
    }
    // dark bottom 15%+
    linearFill(rectPath(R(0, h * 0.78, w, h * 0.22)), [K.obs0.alpha(0), K.obs0.alpha(0.85), K.obs0], P(0, h * 0.78), P(0, h * 0.9), [0, 0.6, 1])
}

// MARK: - UI helpers

func drawShieldShape(_ c: CGPoint, _ s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: P(c.x, c.y - s))
    p.addCurve(to: P(c.x + s * 0.85, c.y - s * 0.7), control1: P(c.x + s * 0.3, c.y - s * 0.75), control2: P(c.x + s * 0.6, c.y - s * 0.7))
    p.addCurve(to: P(c.x, c.y + s), control1: P(c.x + s * 0.9, c.y + s * 0.1), control2: P(c.x + s * 0.5, c.y + s * 0.7))
    p.addCurve(to: P(c.x - s * 0.85, c.y - s * 0.7), control1: P(c.x - s * 0.5, c.y + s * 0.7), control2: P(c.x - s * 0.9, c.y + s * 0.1))
    p.addCurve(to: P(c.x, c.y - s), control1: P(c.x - s * 0.6, c.y - s * 0.7), control2: P(c.x - s * 0.3, c.y - s * 0.75))
    p.closeSubpath()
    return p
}

func drawObsidianShield(_ c: CGPoint, _ s: CGFloat, ow: CGFloat) {
    let outer = drawShieldShape(c, s)
    shadowed(s * 0.06, s * 0.1) { linearFill(outer, [K.gold.lighter(0.3), K.gold, Col(hex: 0x8A4A12)], P(c.x - s, c.y - s), P(c.x + s, c.y + s)) }
    stroke(outer, K.ink, ow)
    let inner = drawShieldShape(P(c.x, c.y + s * 0.04), s * 0.8)
    linearFill(inner, [Col(hex: 0x3A2A44), Col(hex: 0x140A18), K.obs0], P(c.x - s, c.y - s), P(c.x + s, c.y + s))
    clipped(inner) {
        fill(poly([P(c.x - s, c.y - s), P(c.x, c.y - s), P(c.x - s * 0.2, c.y + s), P(c.x - s, c.y + s)]), Col(1, 0.95, 1, 0.07))
        fill(poly([P(c.x - s * 0.5, c.y - s), P(c.x - s * 0.36, c.y - s), P(c.x - s * 0.9, c.y + s * 0.2), P(c.x - s * 1.0, c.y)]), Col(1, 1, 1, 0.18))
    }
    edgeLight(inner, K.molten.alpha(0.5), -s * 0.06, -s * 0.06, blur: s * 0.04)
    stroke(inner, K.ink, ow * 0.7)
    drawEmber(P(c.x, c.y + s * 0.05), s * 0.22, crisp: true, glowAmount: 0.8)
}

func drawMoodSymbol(_ mood: String, _ c: CGPoint, _ r: CGFloat) {
    let baseY = c.y + r * 0.62
    func volcano(_ erupt: CGFloat, col: Col) {
        let v = poly([P(c.x - r * 0.95, baseY + r * 0.4), P(c.x - r * 0.25, c.y - r * 0.12), P(c.x + r * 0.22, c.y - r * 0.12), P(c.x + r * 0.95, baseY + r * 0.4)])
        let sv = smoothClosed([P(c.x - r * 1.1, baseY + r * 0.5), P(c.x - r * 0.6, c.y + r * 0.3), P(c.x - r * 0.24, c.y - r * 0.12), P(c.x + r * 0.22, c.y - r * 0.12), P(c.x + r * 0.6, c.y + r * 0.3), P(c.x + r * 1.1, baseY + r * 0.5)], 0.4)
        _ = v
        halo(P(c.x, c.y - r * 0.15), r * 0.6 * (0.6 + erupt), K.molten.alpha(0.7))
        if erupt > 0 {
            drawFlame(P(c.x, c.y - r * 0.05), r * 0.5 * erupt + r * 0.1, r * 0.9 * erupt, lean: 0, ow: r * 0.04)
        }
        paint(sv, col, ow: r * 0.05, rim: 0.6)
        let lava = ribbon(spline([P(c.x - r * 0.02, c.y - r * 0.1), P(c.x - r * 0.12, c.y + r * 0.2), P(c.x + r * 0.05, c.y + r * 0.45), P(c.x - r * 0.1, baseY + r * 0.4)], 6)) { t in r * (0.06 + 0.1 * t) }
        clipped(sv) { linearFill(lava, [K.hot, K.molten, K.crimson], P(0, c.y), P(0, baseY + r * 0.3)) }
        fill(ellipse(R(c.x - r * 0.24, c.y - r * 0.17, r * 0.46, r * 0.1)), K.hot)
    }
    switch mood {
    case "fury":
        volcano(1.0, col: Col(hex: 0x4A2A2C))
        for (dx, dy, rr0) in [(-0.6, -0.55, 0.12), (0.62, -0.62, 0.1), (-0.35, -0.85, 0.08)] as [(CGFloat, CGFloat, CGFloat)] {
            drawBoulder(P(c.x + r * dx, c.y + r * dy), r * rr0, 0, hot: true, shadow: false)
        }
    case "ashrain":
        let cl = blob(P(c.x, c.y - r * 0.35), r * 0.5, n: 9, seed: 5, jitter: 0.15, sx: 1.4, sy: 0.6)
        paint(cl, Col(hex: 0x6A5A70), ow: r * 0.05, rim: 0.2, rimCol: K.ash)
        for (k, dx) in ([-0.45, -0.1, 0.3, 0.55] as [CGFloat]).enumerated() {
            let y = c.y + r * (0.05 + CGFloat(k % 2) * 0.28)
            stroke(line([P(c.x + r * dx + r * 0.08, y - r * 0.18), P(c.x + r * dx, y)]), K.ash.alpha(0.6), r * 0.04)
            drawRockChip(P(c.x + r * dx, y + r * 0.08), r * 0.1, k)
        }
    case "embershower":
        halo(c, r * 0.9, K.hot.alpha(0.4))
        drawEmber(P(c.x, c.y + r * 0.05), r * 0.3, crisp: true)
        drawEmber(P(c.x - r * 0.48, c.y + r * 0.3), r * 0.2, crisp: true, glowAmount: 0.6)
        drawEmber(P(c.x + r * 0.5, c.y - r * 0.25), r * 0.2, crisp: true, glowAmount: 0.6)
        for q in [P(c.x - r * 0.5, c.y - r * 0.45), P(c.x + r * 0.45, c.y + r * 0.45), P(c.x + r * 0.1, c.y - r * 0.7)] { spark(q, r * 0.05) }
    default:
        volcano(0, col: Col(hex: 0x4A3E40))
        let smoke = smoothOpen([P(c.x, c.y - r * 0.2), P(c.x + r * 0.15, c.y - r * 0.45), P(c.x - r * 0.05, c.y - r * 0.65), P(c.x + r * 0.2, c.y - r * 0.85)])
        stroke(smoke, K.ash.alpha(0.55), r * 0.1)
        for q in [P(-0.55, -0.6), P(0.55, -0.5), P(-0.35, -0.85)] as [CGPoint] { fill(circle(P(c.x + r * q.x, c.y + r * q.y), r * 0.03), Col(1, 0.95, 0.9, 0.8)) }
    }
}

func drawMoodEmblem(_ mood: String, _ c: CGPoint, _ r: CGFloat) {
    let ring: Col, inner: [Col]
    switch mood {
    case "fury": ring = K.crimson; inner = [Col(hex: 0x6A1420), Col(hex: 0x2A060C)]
    case "ashrain": ring = K.ash; inner = [Col(hex: 0x54485A), Col(hex: 0x1E1822)]
    case "embershower": ring = K.hot; inner = [Col(hex: 0x7A3A14), Col(hex: 0x2A1008)]
    default: ring = K.molten2; inner = [Col(hex: 0x4A2028), K.obs1]
    }
    shadowed(r * 0.05, r * 0.1) { fill(circle(c, r), K.ink) }
    let band = circle(c, r * 0.94)
    linearFill(band, [ring.lighter(0.4), ring, ring.darker(0.5)], P(c.x - r, c.y - r), P(c.x + r, c.y + r))
    for i in 0..<12 {
        let a = CGFloat(i) / 12 * .pi * 2
        let q = polar(c, r * 0.85, a)
        fill(circle(q, r * 0.045), ring.darker(0.55)); fill(circle(P(q.x - r * 0.012, q.y - r * 0.012), r * 0.025), ring.lighter(0.5))
    }
    let disc = circle(c, r * 0.74)
    linearFill(disc, inner, P(c.x, c.y - r), P(c.x, c.y + r))
    clipped(disc) { drawMoodSymbol(mood, c, r * 0.74) }
    stroke(disc, K.ink, r * 0.05)
    clipped(band) { fill(ellipse(R(c.x - r * 0.85, c.y - r * 1.05, r * 1.3, r * 0.75)), Col(1, 1, 1, 0.14)) }
    stroke(circle(c, r * 0.97), K.ink, r * 0.05)
}

func drawLavaHeart(_ c: CGPoint, _ s: CGFloat, ow: CGFloat, empty: Bool = false) {
    let h = heartPath(c, s)
    if empty {
        shadowed(s * 0.06, s * 0.1) { linearFill(h, [Col(hex: 0x4A3E44), Col(hex: 0x2A2026), K.obs1], P(c.x - s, c.y - s), P(c.x + s, c.y + s)) }
        clipped(h) {
            let cr = line([P(c.x + s * 0.05, c.y - s * 0.55), P(c.x - s * 0.12, c.y - s * 0.1), P(c.x + s * 0.12, c.y + s * 0.2), P(c.x - s * 0.02, c.y + s * 0.7)])
            stroke(cr, K.obs0, s * 0.08)
            stroke(moved(cr, s * 0.04, s * 0.02), Col(1, 0.9, 0.9, 0.12), s * 0.03)
        }
        edgeLight(h, Col(1, 0.9, 1, 0.2), s * 0.1, s * 0.1, blur: s * 0.06)
        stroke(h, K.ink, ow)
        return
    }
    halo(c, s * 1.5, K.crimson.alpha(0.45))
    shadowed(s * 0.06, s * 0.1) { linearFill(h, [Col(hex: 0xFF7A5A), K.crimson, Col(hex: 0x7A0A1E)], P(c.x - s, c.y - s), P(c.x + s, c.y + s), [0, 0.45, 1]) }
    clipped(h) {
        // cooled crust patches with glowing seams
        for (k, q) in ([P(-0.45, 0.15), P(0.4, -0.2), P(0.1, 0.55), P(-0.2, -0.45)] as [CGPoint]).enumerated() {
            let pl = blob(P(c.x + s * q.x, c.y + s * q.y), s * 0.26, n: 6, seed: UInt64(70 + k), jitter: 0.25, t: 0.5)
            softStroke(pl, K.hot.alpha(0.8), s * 0.06, blur: s * 0.06)
            fill(pl, Col(hex: 0x5A1418, 0.85))
            edgeLight(pl, K.molten.alpha(0.8), -s * 0.04, -s * 0.04, blur: s * 0.02)
        }
        fill(ellipse(R(c.x - s * 0.75, c.y - s * 0.75, s * 0.5, s * 0.35)), Col(1, 1, 1, 0.35))
    }
    edgeLight(h, K.hot.alpha(0.7), -s * 0.1, -s * 0.1, blur: s * 0.06)
    stroke(h, K.ink, ow)
}

func drawBadge(_ earned: Bool) {
    let c = P(60, 60)
    if earned {
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * .pi * 2 - .pi / 2
            withT(c.x, c.y, rot: a + .pi / 2) { drawFlame(P(0, -42), 13, 16, lean: 2, ow: 1.4) }
        }
    }
    let ring = CGMutablePath(); ring.addPath(circle(c, 46)); ring.addPath(circle(c, 31))
    let rimCol = earned ? K.gold : Col(hex: 0x6A6470)
    shadowed(2, 3) { ctx.addPath(ring); ctx.setFillColor(K.ink.cg); ctx.fillPath(using: .evenOdd) }
    ctx.saveGState(); ctx.addPath(ring); ctx.clip(using: .evenOdd)
    ctx.drawLinearGradient(gradient([rimCol.lighter(0.45), rimCol, rimCol.darker(0.5)]), start: P(18, 14), end: P(102, 106), options: [])
    // obsidian band in the middle of the ring
    let band = CGMutablePath(); band.addPath(circle(c, 41)); band.addPath(circle(c, 35.5))
    ctx.addPath(band); ctx.clip(using: .evenOdd)
    ctx.drawLinearGradient(gradient(earned ? [Col(hex: 0x3A2A44), K.obs0] : [Col(hex: 0x4A4650), Col(hex: 0x1E1C22)]), start: P(20, 20), end: P(100, 100), options: [])
    ctx.restoreGState()
    for i in 0..<16 {
        let a = CGFloat(i) / 16 * .pi * 2
        let q = polar(c, 38.2, a)
        if earned { halo(q, 2.4, K.molten.alpha(0.7)); fill(circle(q, 1.1), K.hot) } else { fill(circle(q, 1), Col(0.5, 0.48, 0.52)) }
    }
    stroke(circle(c, 46), K.ink, 2.4); stroke(circle(c, 31), K.ink, 2.4)
    stroke(circle(c, 41), K.ink.alpha(0.7), 1); stroke(circle(c, 35.5), K.ink.alpha(0.7), 1)
    let hl = CGMutablePath(); hl.addArc(center: c, radius: 43.5, startAngle: .pi * 1.05, endAngle: .pi * 1.55, clockwise: false)
    stroke(hl, Col(1, 1, 1, earned ? 0.55 : 0.3), 1.6)
    if !earned {
        for cr in [[P(26, 40), P(31, 46), P(29, 52)], [P(88, 80), P(84, 86), P(87, 92)], [P(70, 18), P(66, 24)]] { stroke(line(cr), K.obs0, 1.2) }
    } else {
        // star studs at the bottom
        for a in [CGFloat.pi * 0.5] { let q = polar(c, 46, a); fill(star(q, 7, 3), K.hot); stroke(star(q, 7, 3), K.ink, 1.2) }
    }
}

func fingerIcon(_ tip: CGPoint, _ s: CGFloat) {
    // a stylised pointing hand (index finger up, knuckles below)
    let f = rr(R(tip.x - s * 0.22, tip.y, s * 0.44, s * 1.2), s * 0.22)
    let palm = rr(R(tip.x - s * 0.55, tip.y + s * 0.75, s * 1.1, s * 0.95), s * 0.35)
    let col = Col(hex: 0xE8D4CC)
    paint(palm, col, ow: s * 0.09, rim: 0.3)
    for k in 0..<3 { stroke(line([P(tip.x - s * 0.05 + CGFloat(k) * s * 0.2, tip.y + s * 0.85), P(tip.x - s * 0.05 + CGFloat(k) * s * 0.2, tip.y + s * 1.1)]), K.ink.alpha(0.4), s * 0.05) }
    paint(f, col, ow: s * 0.09, rim: 0.3)
    fill(rr(R(tip.x - s * 0.13, tip.y + s * 0.08, s * 0.26, s * 0.22), s * 0.1), Col(1, 0.9, 0.9, 0.8))
}

func arrow(_ from: CGPoint, _ to: CGPoint, _ col: Col, _ w: CGFloat) {
    let dx = to.x - from.x, dy = to.y - from.y, l = hypot(dx, dy)
    let ux = dx / l, uy = dy / l
    let headL = w * 2.6
    let shaftEnd = P(to.x - ux * headL * 0.8, to.y - uy * headL * 0.8)
    let head = poly([to, P(to.x - ux * headL - uy * headL * 0.75, to.y - uy * headL + ux * headL * 0.75), P(to.x - ux * headL + uy * headL * 0.75, to.y - uy * headL - ux * headL * 0.75)])
    stroke(line([from, shaftEnd]), K.ink, w + 2.4)
    fill(head, K.ink); stroke(head, K.ink, 2.4)
    softStroke(line([from, shaftEnd]), col.alpha(0.8), w, blur: 3)
    stroke(line([from, shaftEnd]), col, w)
    fill(head, col)
}

// MARK: - Tutorials (320 x 200)

func tutorialBackdrop(_ mood: String = "steady") {
    let top: Col = mood == "fury" ? Col(hex: 0x2A060E) : K.obs0
    linearFill(rectPath(R(0, 0, 320, 200)), [top, K.obs1, K.obs2, Col(hex: 0x5A2224)], P(0, 0), P(0, 160), [0, 0.35, 0.75, 1])
    var g = Rng(s: 5)
    for _ in 0..<40 { fill(circle(P(g.r(0, 320), g.r(0, 90)), g.r(0.3, 0.8)), Col(1, 0.9, 0.85, g.r(0.2, 0.7))) }
    layer {
        withT(250, 60, scale: 0.17) { withT(-300, -46) { drawVolcano(glowSky: true, streams: true) } }
        ctx.setBlendMode(.sourceAtop)
        fill(rectPath(R(0, 0, 320, 200)), K.obs1.alpha(0.45))
        ctx.setBlendMode(.normal)
    }
    linearFill(rectPath(R(0, 100, 320, 70)), [K.obs1.alpha(0), K.obs1.alpha(0.7)], P(0, 100), P(0, 165))
}
func groundStrip(_ y: CGFloat, scale: CGFloat = 0.4, from: CGFloat = 0, to: CGFloat = 320, kind: String = "ground") {
    ctx.saveGState(); ctx.addPath(rectPath(R(from, y, to - from, 200 - y + 1))); ctx.clip()
    var x: CGFloat = 0
    while x < 320 {
        withT(x, y, scale: scale) {
            switch kind {
            case "lava": drawLavaTile()
            case "crust": drawCrustTile()
            default: drawGroundTile()
            }
        }
        x += tileW * scale
    }
    ctx.restoreGState()
}
func tutorial(_ name: String, _ draw: () -> Void) {
    begin(320, 200)
    draw()
    finish(name)
}

// MARK: - Logo

func glyphPath(_ s: String, size: CGFloat) -> (CGPath, [CGRect]) {
    var font = NSFont.systemFont(ofSize: size, weight: .black)
    if let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { font = f }
    let attr = NSAttributedString(string: s, attributes: [.font: font, .kern: size * 0.02])
    let lineRef = CTLineCreateWithAttributedString(attr)
    let runs = CTLineGetGlyphRuns(lineRef) as! [CTRun]
    let path = CGMutablePath()
    var boxes: [CGRect] = []
    for run in runs {
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n)
        var pos = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &pos)
        let attrs = CTRunGetAttributes(run) as NSDictionary
        let runFont = attrs[kCTFontAttributeName as String] as! CTFont
        for i in 0..<n {
            var t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: pos[i].x, ty: 0)
            if let gp = CTFontCreatePathForGlyph(runFont, glyphs[i], &t) {
                path.addPath(gp)
                boxes.append(gp.boundingBox)
            }
        }
    }
    return (path, boxes)
}

// ===================================================================================
// MARK: - Generate
// ===================================================================================

let t0 = Date()

// Scene skies
for mood in ["steady", "fury", "ashrain", "embershower"] {
    begin(430, 932)
    drawSkyScene(mood, w: 430, h: 932)
    finish("bg_sky_\(mood)")
}

begin(600, 760); drawVolcano(); finish("volcano_mountain")

begin(200, 120); drawGroundTile(); finish("ground_tile")
begin(200, 120); drawLavaTile(); finish("lava_tile")
begin(200, 120); drawCrustTile(); finish("crust_tile")
begin(200, 120); drawCrackTile(); finish("crack_warning")

for i in 0..<4 { begin(120, 120); drawBoulder(P(60, 59), 45, i, hot: false); finish("boulder_\(i)") }
for i in 0..<4 { begin(120, 120); drawBoulder(P(60, 59), 45, i, hot: true); finish("boulder_hot_\(i)") }
for i in 0..<3 { begin(28, 28); drawRockChip(P(14, 13.5), 10.5, i); finish("rock_chip_\(i)") }

begin(48, 48); drawEmber(P(24, 25), 8.6); finish("ember")
begin(48, 48); drawHeartShard(P(25, 23), 15); finish("heart_shard")

// Shield bubble
begin(120, 120)
do {
    let c = P(60, 60)
    ctx.drawRadialGradient(gradient([K.molten2.alpha(0), K.molten2.alpha(0.04), K.gold.alpha(0.3), K.hot.alpha(0.75), K.molten.alpha(0.35), K.molten.alpha(0)], [0, 0.55, 0.8, 0.9, 0.95, 1]), startCenter: c, startRadius: 0, endCenter: c, endRadius: 58, options: [])
    stroke(circle(c, 52), Col(hex: 0x3A1E2A, 0.7), 3)
    stroke(circle(c, 52), K.hot.alpha(0.6), 1.2)
    let hl = CGMutablePath(); hl.addArc(center: c, radius: 46, startAngle: .pi * 1.1, endAngle: .pi * 1.45, clockwise: false)
    stroke(hl, Col(1, 1, 1, 0.75), 3.5)
    let hl2 = CGMutablePath(); hl2.addArc(center: c, radius: 46, startAngle: .pi * 1.52, endAngle: .pi * 1.6, clockwise: false)
    stroke(hl2, Col(1, 1, 1, 0.6), 3)
    let lo = CGMutablePath(); lo.addArc(center: c, radius: 48, startAngle: .pi * 0.1, endAngle: .pi * 0.45, clockwise: false)
    stroke(lo, K.molten.alpha(0.7), 2.5)
    for i in 0..<6 { let a = CGFloat(i) / 6 * .pi * 2 + 0.3; let q = polar(c, 52, a); fill(star(q, 3, 0.8, points: 4, rotation: 0), Col(1, 0.95, 0.8, 0.8)) }
}
finish("shield_bubble")

begin(256, 256)
do {
    let c = P(128, 128)
    ctx.drawRadialGradient(gradient([K.molten.alpha(0), K.molten.alpha(0), K.molten.alpha(0.25), K.hot.alpha(0.85), Col(1, 1, 0.9, 1), K.hot.alpha(0.8), K.molten.alpha(0.35), K.crimson.alpha(0)], [0, 0.55, 0.72, 0.83, 0.87, 0.9, 0.95, 1]), startCenter: c, startRadius: 0, endCenter: c, endRadius: 126, options: [])
    var g = Rng(s: 3)
    for _ in 0..<24 { let a = g.r(0, .pi * 2); spark(polar(c, g.r(100, 116), a), g.r(0.8, 1.6)) }
}
finish("shockwave_ring")

// Crater bursts
for k in 0..<4 {
    begin(160, 120)
    let tvals: [CGFloat] = [0.25, 0.5, 0.75, 1.0]
    let t = tvals[k]
    let heights: [CGFloat] = [44, 82, 66, 22], widths: [CGFloat] = [24, 34, 30, 22], alphas: [CGFloat] = [1, 1, 0.85, 0.45]
    let base = P(80, 119), a = alphas[k]
    halo(P(80, 112), 40 + CGFloat(k) * 6, K.molten.alpha(0.6 * a))
    let h = heights[k], w = widths[k]
    let col = CGMutablePath()
    col.move(to: P(base.x - w / 2, base.y))
    col.addCurve(to: P(base.x - w * 0.18, base.y - h), control1: P(base.x - w * 0.2, base.y - h * 0.4), control2: P(base.x - w * 0.5, base.y - h * 0.8))
    col.addQuadCurve(to: P(base.x + w * 0.1, base.y - h * 0.92), control: P(base.x - w * 0.02, base.y - h * 1.12))
    col.addQuadCurve(to: P(base.x + w * 0.26, base.y - h * 0.98), control: P(base.x + w * 0.2, base.y - h * 0.85))
    col.addCurve(to: P(base.x + w / 2, base.y), control1: P(base.x + w * 0.55, base.y - h * 0.7), control2: P(base.x + w * 0.2, base.y - h * 0.35))
    col.closeSubpath()
    softFill(col, K.molten.alpha(0.8 * a), blur: 6)
    linearFill(col, [Col(1, 0.97, 0.85, a), K.hot.alpha(a), K.molten.alpha(a), K.crimson.alpha(a)], base, P(base.x, base.y - h), [0, 0.25, 0.65, 1])
    let core = smoothClosed([P(base.x - w * 0.2, base.y), P(base.x - w * 0.05, base.y - h * 0.6), P(base.x + w * 0.08, base.y - h * 0.55), P(base.x + w * 0.2, base.y)], 0.8)
    fill(core, Col(1, 1, 0.9, 0.7 * a))
    edgeLight(col, Col(0.5, 0.05, 0.05, 0.5 * a), -2, -2, blur: 1.5)
    var g = Rng(s: 99)
    for i in 0..<16 {
        let ang = -CGFloat.pi / 2 + g.r(-0.95, 0.95)
        let v = g.r(170, 260), grav: CGFloat = 330
        let x = base.x + cos(ang) * v * 0.32 * t
        let y = base.y - 6 + sin(ang) * v * t + 0.5 * grav * t * t
        let rr0 = g.r(1.6, 4) * (1.1 - t * 0.4)
        if y > 122 || y < -4 || x < -4 || x > 164 { continue }
        let da = a * (i % 3 == 0 ? 0.8 : 1)
        halo(P(x, y), rr0 * 3, K.molten.alpha(0.6 * da))
        let vy = sin(ang) * v + grav * t
        let tail = P(x - cos(ang) * v * 0.32 * 0.03, y - vy * 0.03)
        stroke(line([tail, P(x, y)]), K.molten2.alpha(da * 0.8), rr0 * 1.2)
        fill(circle(P(x, y), rr0), K.hot.alpha(da))
        fill(circle(P(x - rr0 * 0.3, y - rr0 * 0.3), rr0 * 0.45), Col(1, 1, 0.9, da))
    }
    finish("crater_burst_\(k)")
}

// Heroes
for skin in skinOrder {
    for f in 0..<4 {
        begin(90, 110)
        withT(45, 104) { drawHero(skin, frame: f) }
        finish("hero_\(skin)_run_\(f)")
    }
    begin(300, 300)
    let gl = looks[skin]!.g
    halo(P(150, 150), 150, gl.alpha(0.55))
    halo(P(150, 140), 80, gl.lighter(0.3).alpha(0.35))
    var g = Rng(s: UInt64(skin.count * 13))
    ctx.saveGState(); ctx.setBlendMode(.normal)
    for i in 0..<18 {
        let a = CGFloat(i) / 18 * .pi * 2
        let ray = poly([P(150, 150), polar(P(150, 150), 150, a - 0.05), polar(P(150, 150), 150, a + 0.05)])
        radialFill(ray, [gl.alpha(0.18), gl.alpha(0)], P(150, 150), 150)
    }
    ctx.restoreGState()
    stroke(circle(P(150, 150), 118), gl.alpha(0.25), 2)
    for _ in 0..<26 { spark(P(g.r(20, 280), g.r(20, 280)), g.r(0.6, 1.6), gl.lighter(0.4).alpha(g.r(0.4, 0.9))) }
    withT(150, 284, scale: 2.8) { drawHero(skin, frame: -1) }
    finish("hero_\(skin)_portrait")
}

// Logo
begin(600, 170)
do {
    let (raw, rawBoxes) = glyphPath("MAGMA RUN", size: 100)
    let bb = raw.boundingBox
    let sc = min(540 / bb.width, 98 / bb.height)
    var t = CGAffineTransform(translationX: 300, y: 128).scaledBy(x: sc, y: sc).translatedBy(x: -bb.midX, y: -bb.maxY)
    let G = raw.copy(using: &t)!
    let boxes = rawBoxes.map { $0.applying(t) }
    let gb = G.boundingBox
    // shadow + outline encompassing the extruded rock
    shadowed(5, 8, Col(0, 0, 0, 0.6)) {
        for dy in stride(from: 0.0, through: 7.0, by: 1.0) { stroke(moved(G, 0, dy), K.ink, 11); fill(moved(G, 0, dy), K.ink) }
    }
    // cooled-rock extrusion
    for dy in stride(from: 7.0, through: 1.0, by: -1.0) {
        let tone = K.basalt.mix(K.basaltD, CGFloat(dy) / 7)
        fill(moved(G, 0, dy), tone)
    }
    clipped(moved(G, 0, 7)) {
        var g = Rng(s: 77)
        for _ in 0..<160 { fill(circle(P(g.r(gb.minX, gb.maxX), g.r(gb.midY, gb.maxY + 8)), g.r(0.4, 1.1)), Col(0, 0, 0, 0.35)) }
    }
    // molten face
    linearFill(G, [Col(1, 0.96, 0.75), K.hot, K.molten2, K.molten, K.crimson], P(0, gb.minY), P(0, gb.maxY), [0, 0.18, 0.45, 0.72, 1])
    clipped(G) {
        var g = Rng(s: 78)
        for _ in 0..<26 {
            var p = P(g.r(gb.minX, gb.maxX), g.r(gb.minY + 20, gb.maxY))
            var pts = [p]
            for _ in 0..<3 { p = P(p.x + g.r(-7, 7), p.y + g.r(-6, 6)); pts.append(p) }
            stroke(line(pts), Col(0.55, 0.08, 0.06, 0.4), 1.2)
        }
        // crust plates at the bottom
        for _ in 0..<18 {
            let p = P(g.r(gb.minX, gb.maxX), gb.maxY - g.r(0, 12))
            fill(blob(p, g.r(3, 7), n: 6, seed: UInt64(g.r(1, 999)), jitter: 0.3, sx: 1.6, sy: 0.6), Col(hex: 0x4A1418, 0.55))
        }
    }
    edgeLight(G, Col(1, 1, 0.92, 0.85), 2.2, 2.2, blur: 1.4)
    edgeLight(G, Col(hex: 0x6A0A1A, 0.6), -2.4, -2.6, blur: 1.6)
    stroke(G, K.ink, 2.4)
    // lava drips under selected letters
    let dripLetters = [0, 2, 3, 6, 8]
    for (k, i) in dripLetters.enumerated() where i < boxes.count {
        let b = boxes[i]
        let x = b.minX + b.width * (k % 2 == 0 ? 0.3 : 0.62)
        let len: CGFloat = 9 + CGFloat(k % 3) * 5
        let topY = b.maxY + 2
        let d = CGMutablePath()
        d.move(to: P(x - 4, topY))
        d.addCurve(to: P(x - 2.4, topY + len), control1: P(x - 2, topY + 2), control2: P(x - 2.6, topY + len * 0.6))
        d.addArc(center: P(x, topY + len), radius: 2.4, startAngle: .pi, endAngle: 0, clockwise: true)
        d.addCurve(to: P(x + 4, topY), control1: P(x + 2.6, topY + len * 0.6), control2: P(x + 2, topY + 2))
        d.closeSubpath()
        stroke(d, K.ink, 3)
        linearFill(d, [K.molten, K.molten2, K.hot], P(0, topY), P(0, topY + len + 2.4))
        fill(circle(P(x - 0.8, topY + len - 0.6), 0.9), Col(1, 1, 0.9, 0.9))
    }
    // volcano flame accent on the last A of MAGMA
    if boxes.count > 4 {
        let a = boxes[4]
        let apex = P(a.midX, a.minY + 2)
        halo(P(apex.x, apex.y - 10), 26, K.molten.alpha(0.7))
        drawFlame(P(apex.x, apex.y + 4), 15, 30, lean: 3, ow: 2)
        spark(P(apex.x - 14, apex.y - 18), 1.4); spark(P(apex.x + 15, apex.y - 26), 1.1); spark(P(apex.x + 4, apex.y - 36), 0.9)
    }
    spark(P(gb.minX + 6, gb.minY + 6), 2.0, Col(1, 1, 0.9, 1)); spark(P(gb.maxX - 12, gb.minY + 10), 1.6, Col(1, 1, 0.9, 1))
}
finish("logo_wordmark")

// Home backdrop
begin(430, 932)
do {
    drawSkyScene("steady", w: 430, h: 932)
    // volcano far away in the upper half
    withT(215, 215, scale: 0.5) { withT(-300, -46) { drawVolcano() } }
    halo(P(215, 205), 110, K.molten.alpha(0.35))
    // plume
    var g = Rng(s: 404)
    for i in 0..<9 {
        let c = P(215 + CGFloat(i) * 9 + g.r(-8, 8), 190 - CGFloat(i) * 16)
        softFill(circle(c, 12 + CGFloat(i) * 3.5), Col(hex: 0x3A2430, 0.55), blur: 8)
    }
    for _ in 0..<40 { spark(P(215 + g.r(-50, 70), g.r(80, 210)), g.r(0.5, 1.2), K.hot.alpha(g.r(0.5, 1))) }
    // haze and foothills hiding the volcano base
    blurredLayer(14) { fill(rectPath(R(-20, 500, 470, 60)), Col(hex: 0x4A1E22, 0.8)) }
    ridge(560, amp: 46, seed: 31, w: 430, h: 932, cols: [Col(hex: 0x24121A), Col(hex: 0x140A10)], rimCol: K.molten.alpha(0.45))
    ridge(598, amp: 30, seed: 32, w: 430, h: 932, cols: [Col(hex: 0x180C12), K.obs0], rimCol: K.molten.alpha(0.55))
    // a lava river winding toward the viewer, widening with perspective
    let river = spline([P(232, 600), P(250, 640), P(196, 690), P(250, 760), P(150, 850), P(210, 940)], 14)
    let rib = ribbon(river) { t in 2 + 26 * t * t }
    softFill(rib, K.molten.alpha(0.7), blur: 10)
    linearFill(rib, [K.molten, K.hot, K.molten2, K.crimson], P(0, 600), P(0, 940), [0, 0.3, 0.7, 1])
    clipped(rib) { for i in stride(from: 20, to: river.count - 4, by: 7) { let q = river[i]; fill(blob(q, 1 + CGFloat(i) * 0.06, n: 5, seed: UInt64(i), jitter: 0.3, sx: 1.6, sy: 0.7), K.obs2.alpha(0.6)) } }
    for (q, r) in [(P(90, 650), 10.0), (P(340, 680), 14.0), (P(60, 740), 8.0)] as [(CGPoint, CGFloat)] {
        let pool = ellipse(R(q.x - r * 2, q.y - r * 0.4, r * 4, r * 0.8))
        softFill(pool, K.molten.alpha(0.6), blur: 6); linearFill(pool, [K.hot, K.molten], P(0, q.y - r * 0.4), P(0, q.y + r * 0.4))
    }
    // calm darker middle for cards
    linearFill(rectPath(R(0, 300, 430, 632)), [K.obs0.alpha(0), K.obs0.alpha(0.55), K.obs0.alpha(0.75)], P(0, 300), P(0, 820), [0, 0.5, 1])
    // foreground rocks
    let rocks: [(CGPoint, CGFloat, Int)] = [(P(20, 900), 70, 1), (P(410, 910), 80, 3), (P(120, 950), 60, 0), (P(300, 960), 65, 2), (P(-10, 800), 45, 2), (P(445, 790), 50, 0)]
    for (c, r, i) in rocks {
        let path = boulderPath(c, r, i)
        linearFill(path, [Col(hex: 0x2A1A20), Col(hex: 0x120A0E)], P(c.x, c.y - r), P(c.x, c.y + r))
        edgeLight(path, K.molten.alpha(0.5), -4, -4, blur: 3)
        edgeLight(path, Col(0.8, 0.7, 0.8, 0.12), 3, 3, blur: 2)
        stroke(path, K.ink, 2)
    }
    for _ in 0..<30 { spark(P(g.r(0, 430), g.r(600, 900)), g.r(0.4, 1.0), K.molten2.alpha(g.r(0.3, 0.8))) }
}
finish("home_backdrop")

// Menu icons
begin(160, 160)
do {
    fill(ellipse(R(28, 128, 104, 12)), Col(0, 0, 0, 0.4))
    let anvil = smoothClosed([P(22, 70), P(46, 62), P(126, 62), P(134, 68), P(134, 84), P(112, 88), P(102, 104), P(116, 118), P(124, 132), P(38, 132), P(46, 118), P(60, 104), P(54, 90), P(44, 84)], 0.25)
    paint(anvil, Col(hex: 0x4A4450), ow: 2.8, rim: 0.7)
    fill(rr(R(48, 63, 84, 4), 2), Col(1, 1, 1, 0.25))
    // glowing ingot
    let ingot = rr(R(70, 53, 36, 10), 3)
    halo(P(88, 58), 26, K.molten.alpha(0.8))
    linearFill(ingot, [Col(1, 0.97, 0.8), K.hot, K.molten], P(0, 53), P(0, 63)); stroke(ingot, K.ink, 2)
    // hammer
    withT(104, 46, rot: -0.75) {
        let handle = rr(R(-4, -6, 8, 56), 4)
        paint(handle, Col(hex: 0x6A3A24), ow: 2.4, rim: 0.4)
        let head = rr(R(-22, -24, 44, 20), 5)
        halo(P(0, -14), 30, K.molten.alpha(0.7))
        paint(head, Col(hex: 0x5A5260), ow: 2.6, rim: 0.8, rimCol: K.hot)
        let face = rr(R(14, -24, 8, 20), 3)
        linearFill(face, [K.hot, K.molten], P(14, -24), P(22, -4)); stroke(face, K.ink, 2)
    }
    var g = Rng(s: 8)
    for _ in 0..<10 { spark(P(88 + g.r(-36, 36), 50 + g.r(-26, 6)), g.r(0.8, 1.8)) }
}
finish("menu_forge")

begin(160, 160)
do {
    halo(P(80, 80), 70, K.molten.alpha(0.35))
    withT(56, 140, scale: 1.3) { drawHero("ashRunner", frame: -1) }
    withT(104, 146, scale: 1.35) { drawHero("magmaTitan", frame: 0) }
}
finish("menu_heroes")

begin(160, 160)
do {
    fill(ellipse(R(40, 134, 80, 10)), Col(0, 0, 0, 0.4))
    halo(P(80, 40), 50, K.molten.alpha(0.6))
    // handles
    for side in [-1.0, 1.0] as [CGFloat] {
        let h = CGMutablePath(); h.move(to: P(80 + side * 30, 62)); h.addCurve(to: P(80 + side * 26, 92), control1: P(80 + side * 52, 60), control2: P(80 + side * 48, 92))
        stroke(h, K.ink, 10); stroke(h, K.gold.darker(0.2), 5.5); stroke(h, K.gold.lighter(0.3).alpha(0.7), 2)
    }
    let cup = CGMutablePath()
    cup.move(to: P(44, 54)); cup.addLine(to: P(116, 54))
    cup.addCurve(to: P(86, 106), control1: P(116, 84), control2: P(100, 100))
    cup.addLine(to: P(74, 106))
    cup.addCurve(to: P(44, 54), control1: P(60, 100), control2: P(44, 84)); cup.closeSubpath()
    drawFlame(P(80, 58), 40, 48, lean: 4, ow: 2.4)
    let cb = cup.boundingBox
    linearFill(cup, [Col(hex: 0x4A3A54), Col(hex: 0x1A1020), K.obs0], P(cb.minX, cb.minY), P(cb.maxX, cb.maxY))
    clipped(cup) {
        fill(poly([P(56, 50), P(66, 50), P(74, 110), P(68, 110)]), Col(1, 1, 1, 0.16))
        fill(poly([P(70, 50), P(73, 50), P(78, 110), P(76, 110)]), Col(1, 1, 1, 0.12))
    }
    edgeLight(cup, K.molten.alpha(0.6), -3, -3, blur: 2)
    stroke(cup, K.ink, 2.8)
    let rim = rr(R(40, 50, 80, 8), 4); paint(rim, K.gold, ow: 2.4, rim: 0.5)
    let stem = poly([P(74, 104), P(86, 104), P(84, 120), P(76, 120)]); paint(stem, K.gold.darker(0.15), ow: 2.4, rim: 0.4)
    let base = rr(R(54, 118, 52, 16), 4); paint(base, Col(hex: 0x2A1E2E), ow: 2.6, rim: 0.6)
    fill(rr(R(58, 120, 44, 3), 1.5), K.gold.alpha(0.9))
    drawEmber(P(80, 78), 6, crisp: true, glowAmount: 0.6)
}
finish("menu_records")

begin(160, 160)
do {
    fill(ellipse(R(30, 136, 100, 10)), Col(0, 0, 0, 0.4))
    let tab = CGMutablePath()
    tab.move(to: P(36, 140)); tab.addLine(to: P(36, 50))
    tab.addCurve(to: P(124, 50), control1: P(36, 14), control2: P(124, 14))
    tab.addLine(to: P(124, 140)); tab.closeSubpath()
    shadowed(3, 5) { paint(tab, Col(hex: 0x5A4A50), ow: 0, rim: 0.6) }
    clipped(tab) {
        var g = Rng(s: 6)
        for _ in 0..<80 { fill(circle(P(g.r(36, 124), g.r(20, 140)), g.r(0.4, 1.4)), Col(0, 0, 0, 0.3)) }
        let cr = line([P(118, 60), P(110, 70), P(114, 82)]); stroke(cr, K.obs0.alpha(0.8), 1.4)
    }
    let inset = CGMutablePath()
    inset.move(to: P(46, 132)); inset.addLine(to: P(46, 54)); inset.addCurve(to: P(114, 54), control1: P(46, 26), control2: P(114, 26)); inset.addLine(to: P(114, 132)); inset.closeSubpath()
    fill(inset, Col(hex: 0x2E2228, 0.8))
    edgeLight(inset, Col(0, 0, 0, 0.6), 2.5, 2.5, blur: 1.5)
    edgeLight(inset, Col(1, 0.9, 0.9, 0.18), -1.5, -1.5)
    stroke(tab, K.ink, 2.8)
    // carved flame glyph
    halo(P(80, 72), 30, K.molten.alpha(0.7))
    let glyph = flamePath(P(80, 92), 30, 46, lean: 3)
    softFill(glyph, K.molten.alpha(0.9), blur: 4)
    linearFill(glyph, [K.hot, K.molten2, K.molten], P(80, 92), P(80, 46))
    stroke(glyph, Col(hex: 0x6A1A10), 1.6)
    fill(flamePath(P(80, 90), 13, 22, lean: 1), Col(1, 0.98, 0.85, 0.9))
    for (k, y) in ([104.0, 113, 122] as [CGFloat]).enumerated() {
        let w: CGFloat = k == 1 ? 44 : 54
        stroke(line([P(80 - w / 2, y), P(80 + w / 2, y)]), K.obs0, 3)
        stroke(line([P(80 - w / 2, y + 1.2), P(80 + w / 2, y + 1.2)]), K.molten.alpha(0.55), 1)
    }
}
finish("menu_howto")

// Upgrades (200 x 200)
begin(200, 200)
do {
    fill(ellipse(R(40, 164, 120, 12)), Col(0, 0, 0, 0.4))
    for (k, y) in ([92.0, 112, 132] as [CGFloat]).enumerated() { stroke(line([P(20 + CGFloat(k) * 6, y), P(56 + CGFloat(k) * 4, y)]), K.molten2.alpha(0.7), 3) }
    // wing behind the heel: three fanned feathers
    for (k, a) in ([-2.75, -2.35, -1.95] as [CGFloat]).enumerated() {
        withT(84, 80, rot: a + .pi / 2) {
            let L: CGFloat = 58 - CGFloat(k) * 6
            let f = smoothClosed([P(0, 0), P(-8, -L * 0.35), P(-3, -L), P(9, -L * 0.45)], 0.9)
            paint(f, Col(hex: 0xEDE2DA), ow: 2.6, rim: 0.6)
            clipped(f) { fill(rectPath(R(-12, -L - 2, 24, L * 0.3)), K.gold.alpha(0.85)); stroke(line([P(0, -2), P(-2, -L + 6)]), K.ash.darker(0.3).alpha(0.7), 1.2) }
            stroke(f, K.ink, 2.6)
        }
    }
    let boot = CGMutablePath()
    boot.move(to: P(82, 46)); boot.addLine(to: P(124, 46)); boot.addLine(to: P(122, 112))
    boot.addCurve(to: P(168, 132), control1: P(146, 114), control2: P(166, 118))
    boot.addCurve(to: P(160, 160), control1: P(172, 146), control2: P(170, 158))
    boot.addLine(to: P(80, 160)); boot.addCurve(to: P(82, 46), control1: P(74, 120), control2: P(84, 80)); boot.closeSubpath()
    paint(boot, Col(hex: 0x6A3A2A), ow: 3, rim: 0.7)
    let sole = rr(R(76, 152, 92, 12), 5); paint(sole, Col(hex: 0x2A1E22), ow: 2.6, rim: 0.6)
    let cuff = rr(R(76, 40, 54, 16), 5); paint(cuff, K.molten, ow: 2.6, rim: 0.5, rimCol: K.hot)
    for y in [74.0, 90, 106] as [CGFloat] { stroke(line([P(96, y), P(116, y - 4)]), K.hot, 2.2) }
    stroke(line([P(124, 124), P(150, 140)]), K.molten.alpha(0.8), 2.4)
    drawEmber(P(102, 128), 6, crisp: true, glowAmount: 0.6)
}
finish("upgrade_agility")

begin(200, 200); fill(ellipse(R(50, 168, 100, 12)), Col(0, 0, 0, 0.35)); drawLavaHeart(P(100, 98), 70, ow: 3); finish("upgrade_vitality")
begin(200, 200); fill(ellipse(R(50, 172, 100, 12)), Col(0, 0, 0, 0.35)); drawObsidianShield(P(100, 98), 74, ow: 3); finish("upgrade_shield")

begin(200, 200)
do {
    // embers pulled in on trails
    for (k, q) in ([P(160, 40), P(176, 92), P(150, 150)] as [CGPoint]).enumerated() {
        let trail = smoothOpen([P(q.x + 30, q.y + CGFloat(k - 1) * 8), P(q.x + 12, q.y + CGFloat(k - 1) * 2), q])
        softStroke(trail, K.molten.alpha(0.6), 3, blur: 3)
        drawEmber(q, 7.5, crisp: true, glowAmount: 0.6)
    }
    let m = CGMutablePath()
    m.addArc(center: P(86, 100), radius: 48, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
    let magnetPath = m.copy(strokingWithWidth: 30, lineCap: .butt, lineJoin: .round, miterLimit: 10)
    shadowed(4, 6) { paint(magnetPath, K.crimson, ow: 0, rim: 0.6) }
    clipped(magnetPath) {
        let hl = CGMutablePath(); hl.addArc(center: P(86, 100), radius: 56, startAngle: -.pi / 2, endAngle: .pi * 0.85, clockwise: true)
        stroke(hl, Col(1, 0.9, 0.9, 0.35), 4)
    }
    stroke(magnetPath, K.ink, 3)
    for y in [52.0, 148] as [CGFloat] {
        let tip = rr(R(86, y - 15, 30, 30), 3)
        paint(tip, Col(hex: 0xD8D0D8), ow: 3, rim: 0.7, rimCol: K.hot)
    }
    ctx.saveGState(); ctx.setLineDash(phase: 0, lengths: [4, 5])
    for k in 0..<3 {
        let f = CGMutablePath(); let rx = 14 + CGFloat(k) * 10
        f.move(to: P(118, 52)); f.addCurve(to: P(118, 148), control1: P(118 + rx * 2.2, 52 - rx * 0.3), control2: P(118 + rx * 2.2, 148 + rx * 0.3))
        stroke(f, K.hot.alpha(0.55 - CGFloat(k) * 0.12), 1.6)
    }
    ctx.restoreGState()
}
finish("upgrade_magnet")

begin(200, 200)
do {
    fill(ellipse(R(36, 168, 128, 12)), Col(0, 0, 0, 0.4))
    halo(P(100, 100), 80, K.molten.alpha(0.5))
    // ember pile
    let pile: [(CGFloat, CGFloat, CGFloat)] = [(70, 104, 9), (100, 100, 10), (130, 104, 9), (84, 88, 9), (116, 86, 9.5), (100, 70, 10), (58, 112, 7), (142, 112, 7)]
    for e in pile { drawEmber(P(e.0, e.1), e.2, crisp: true, glowAmount: 0.4) }
    let bowl = CGMutablePath()
    bowl.move(to: P(30, 108)); bowl.addLine(to: P(170, 108))
    bowl.addCurve(to: P(124, 164), control1: P(170, 140), control2: P(150, 160))
    bowl.addLine(to: P(76, 164)); bowl.addCurve(to: P(30, 108), control1: P(50, 160), control2: P(30, 140)); bowl.closeSubpath()
    paint(bowl, Col(hex: 0x4A3E44), ow: 3, rim: 0.7)
    clipped(bowl) {
        for k in 0..<3 { stroke(smoothOpen([P(30, 120 + CGFloat(k) * 12), P(100, 126 + CGFloat(k) * 12), P(170, 120 + CGFloat(k) * 12)]), Col(0, 0, 0, 0.3), 1.4) }
        let cr = line([P(60, 112), P(66, 126), P(60, 138)]); softStroke(cr, K.molten, 1.4, blur: 2); stroke(cr, K.hot, 0.8)
    }
    let lip = ellipse(R(26, 100, 148, 16)); paint(lip, Col(hex: 0x5A4E54), ow: 3, rim: 0.4)
    fill(ellipse(R(36, 103, 128, 10)), Col(hex: 0x6A2A18))
    clipped(ellipse(R(36, 103, 128, 10))) { halo(P(100, 108), 60, K.hot.alpha(0.9)) }
    for e in [(80.0, 102.0, 8.0), (104, 100, 9), (124, 103, 7.5)] as [(CGFloat, CGFloat, CGFloat)] { drawEmber(P(e.0, e.1), e.2, crisp: true, glowAmount: 0.3) }
    for q in [P(64, 50), P(140, 56), P(100, 36)] { spark(q, 1.6) }
}
finish("upgrade_fortune")

begin(64, 64); drawEmber(P(32, 34), 11.4, crisp: true, glowAmount: 0.45); finish("icon_ember")

// HUD
begin(64, 64); drawLavaHeart(P(32, 33), 25, ow: 2.6); finish("hud_heart_full")
begin(64, 64); drawLavaHeart(P(32, 33), 25, ow: 2.6, empty: true); finish("hud_heart_empty")
begin(64, 64); drawObsidianShield(P(32, 32), 26, ow: 2.6); finish("hud_shield")
begin(64, 64)
do {
    let c = P(32, 32)
    halo(c, 30, K.crimson.alpha(0.5))
    let burst = smoothClosed((0..<24).map { i in polar(c, i % 2 == 0 ? 28 : 18, CGFloat(i) / 24 * .pi * 2) }, 0.2)
    paint(burst, K.crimson, ow: 2.4, rim: 0.7, rimCol: K.hot)
    let inner = circle(c, 15)
    radialFill(inner, [Col(1, 0.97, 0.8), K.hot, K.molten], P(c.x - 3, c.y - 3), 16)
    stroke(inner, K.ink, 2.2)
    // angry brows / eyes
    for side in [-1.0, 1.0] as [CGFloat] {
        stroke(line([P(c.x + side * 10, c.y - 7), P(c.x + side * 2.5, c.y - 3)]), K.ink, 2.6)
        fill(ellipse(R(c.x + side * 5.5 - 2, c.y - 2.5, 4, 4.5)), K.ink)
    }
    let mouth = CGMutablePath(); mouth.move(to: P(c.x - 5, c.y + 8)); mouth.addQuadCurve(to: P(c.x + 5, c.y + 8), control: P(c.x, c.y + 4))
    stroke(mouth, K.ink, 2.2)
}
finish("hud_rage")
begin(64, 64)
do {
    halo(P(32, 32), 30, K.molten.alpha(0.6))
    drawFlame(P(32, 60), 40, 56, lean: 2, ow: 0)
    stroke(flamePath(P(32, 60), 40, 56, lean: 2), K.ink, 2.4)
    let bolt = poly([P(36, 10), P(20, 36), P(30, 36), P(25, 56), P(44, 28), P(34, 28), P(40, 10)])
    shadowed(1, 1.5) { linearFill(bolt, [Col(1, 1, 0.95), K.hot], P(0, 10), P(0, 56)) }
    stroke(bolt, K.ink, 2.2)
}
finish("hud_overdrive")
begin(64, 64); drawHeartShard(P(33, 31), 20, crisp: true, glowAmount: 0.6); finish("hud_shard")
begin(64, 64)
do {
    let slab = poly([P(10, 24), P(30, 12), P(54, 20), P(56, 42), P(34, 54), P(10, 46)])
    halo(P(32, 36), 30, K.molten.alpha(0.35))
    shadowed(1.5, 2) { linearFill(slab, [Col(hex: 0x3A2A48), Col(hex: 0x120A16), K.obs0], P(10, 12), P(56, 54)) }
    clipped(slab) {
        fill(poly([P(10, 24), P(30, 12), P(32, 32), P(10, 36)]), Col(1, 0.95, 1, 0.12))
        fill(poly([P(20, 12), P(26, 12), P(14, 54), P(8, 54)]), Col(1, 1, 1, 0.12))
        let cr = line([P(30, 12), P(32, 26), P(26, 34), P(34, 54)])
        softStroke(cr, K.molten.alpha(1), 2.5, blur: 2.5); stroke(cr, K.molten, 1.4); stroke(cr, K.hot, 0.6)
        let cr2 = line([P(32, 26), P(44, 30), P(56, 28)])
        softStroke(cr2, K.molten.alpha(0.9), 2, blur: 2); stroke(cr2, K.molten, 1)
    }
    edgeLight(slab, Col(0.95, 0.85, 1, 0.35), 1.5, 1.5, blur: 1)
    stroke(slab, K.ink, 2.6)
    fill(ellipse(R(16, 22, 9, 4)), Col(1, 1, 1, 0.5))
    spark(P(48, 14), 1.6, Col(1, 1, 1, 1))
}
finish("hud_crust")

// Mood emblems
for mood in ["steady", "fury", "ashrain", "embershower"] {
    begin(96, 96); drawMoodEmblem(mood, P(48, 47), 44); finish("mood_\(mood)")
}

// Tutorials
tutorial("tutorial_controls") {
    tutorialBackdrop()
    groundStrip(158)
    withT(160, 160, scale: 0.85) { drawHero("emberScout", frame: 1) }
    arrow(P(124, 116), P(70, 116), K.hot, 5.5)
    arrow(P(196, 116), P(250, 116), K.hot, 5.5)
    // finger drag with ripple + trail
    stroke(line([P(222, 150), P(268, 150)]), Col(1, 0.95, 0.85, 0.35), 4)
    for (k, r) in ([6.0, 11, 16] as [CGFloat]).enumerated() { stroke(circle(P(268, 150), r), Col(1, 0.95, 0.85, 0.7 - CGFloat(k) * 0.2), 1.6) }
    fingerIcon(P(268, 146), 24)
}
tutorial("tutorial_rage") {
    tutorialBackdrop("fury")
    groundStrip(158)
    let hc = P(160, 128)
    halo(hc, 80, K.molten.alpha(0.35))
    ctx.drawRadialGradient(gradient([K.molten.alpha(0), K.molten.alpha(0), K.hot.alpha(0.9), Col(1, 1, 0.9, 1), K.molten.alpha(0.3), K.molten.alpha(0)], [0, 0.6, 0.84, 0.88, 0.94, 1]), startCenter: hc, startRadius: 0, endCenter: hc, endRadius: 70, options: [])
    withT(160, 160, scale: 0.8) { drawHero("magmaTitan", frame: -1) }
    drawBoulder(P(80, 70), 14, 1, hot: false)
    for (k, q) in ([P(236, 76), P(248, 64), P(224, 60), P(256, 84)] as [CGPoint]).enumerated() { drawRockChip(q, 5, k % 3) }
    for q in [P(242, 72), P(230, 84)] { spark(q, 2) }
    // rage bar
    let bar = rr(R(90, 14, 140, 14), 7)
    fill(bar, K.obs0.alpha(0.8)); stroke(bar, K.ink, 3)
    let fillBar = rr(R(93, 17, 134, 8), 4)
    linearFill(fillBar, [K.crimson, K.molten, K.hot], P(93, 0), P(227, 0))
    fill(rr(R(95, 18, 128, 2.4), 1.2), Col(1, 1, 1, 0.45))
    stroke(bar, K.hot.alpha(0.5), 1)
    withT(78, 21, scale: 0.4) { withT(-32, -32) {
        let c = P(32, 32)
        let burst = smoothClosed((0..<24).map { i in polar(c, i % 2 == 0 ? 28 : 18, CGFloat(i) / 24 * .pi * 2) }, 0.2)
        paint(burst, K.crimson, ow: 3, rim: 0.7, rimCol: K.hot)
        radialFill(circle(c, 15), [Col(1, 0.97, 0.8), K.hot, K.molten], c, 16)
    } }
}
tutorial("tutorial_lava") {
    tutorialBackdrop()
    groundStrip(158)
    groundStrip(158, scale: 0.4, from: 190, to: 320, kind: "lava")
    withT(40, 158, scale: 0.4) { drawCrackTile() }
    withT(120, 158, scale: 0.4) { drawCrackTile() }
    ctx.saveGState(); ctx.addPath(rectPath(R(0, 0, 190, 200))); ctx.clip()
    ctx.restoreGState()
    halo(P(255, 158), 70, K.molten.alpha(0.5))
    for x in stride(from: 200.0, to: 320, by: 22) { drawFlame(P(x, 160), 8, 12 + CGFloat(Int(x) % 3) * 4, lean: 1) }
    withT(70, 160, scale: 0.82) { drawHero("ashRunner", frame: 2) }
    arrow(P(112, 84), P(36, 84), K.hot, 4.5)
    // warning glyph over the cracks
    let tri = poly([P(150, 96), P(166, 124), P(134, 124)])
    halo(P(150, 114), 26, K.molten.alpha(0.6))
    paint(tri, K.hot, ow: 2.4, rim: 0.4, rimCol: K.molten)
    fill(rr(R(148.4, 104, 3.2, 11), 1.6), K.ink); fill(circle(P(150, 119.4), 1.8), K.ink)
}
tutorial("tutorial_overdrive") {
    tutorialBackdrop()
    groundStrip(158)
    for i in 0..<6 {
        let x = 70 + CGFloat(i) * 36
        drawEmber(P(x, 32), 7, crisp: true, glowAmount: 0.6)
    }
    stroke(line([P(70, 52), P(250, 52)]), K.hot.alpha(0.4), 2)
    halo(P(150, 128), 60, K.molten.alpha(0.7))
    withT(150, 160, scale: 0.85) { drawHero("phoenix", frame: 1, molten: true) }
    for k in 0..<4 { let y = 110 + CGFloat(k) * 10; stroke(line([P(100 - CGFloat(k) * 6, y), P(122, y)]), K.hot.alpha(0.7), 2.2) }
    drawBoulder(P(214, 106), 14, 2, hot: true)
    for (k, q) in ([P(236, 92), P(242, 112), P(230, 124)] as [CGPoint]).enumerated() { drawRockChip(q, 5, k, hot: true) }
    spark(P(222, 96), 2.4)
}
tutorial("tutorial_moods") {
    tutorialBackdrop()
    groundStrip(170)
    for (i, mood) in ["steady", "fury", "ashrain", "embershower"].enumerated() {
        let x = 46 + CGFloat(i) * 76
        drawMoodEmblem(mood, P(x, 100), 30)
        if i < 3 { arrow(P(x + 33, 100), P(x + 43, 100), K.ash, 2.4) }
    }
}
tutorial("tutorial_crust") {
    tutorialBackdrop()
    groundStrip(158)
    groundStrip(158, scale: 0.4, from: 90, to: 230, kind: "crust")
    stroke(line([P(90, 158), P(90, 200)]), K.ink, 1.6); stroke(line([P(230, 158), P(230, 200)]), K.ink, 1.6)
    withT(160, 160, scale: 0.85) { drawHero("crystalSpirit", frame: 0) }
    // doubling chevrons
    for k in 0..<2 {
        let y = 72 - CGFloat(k) * 14
        let ch = line([P(144, y + 10), P(160, y), P(176, y + 10)])
        stroke(ch, K.ink, 8); softStroke(ch, K.hot.alpha(0.8), 5, blur: 3); stroke(ch, K.hot, 5)
    }
    for (k, q) in ([P(110, 150), P(206, 148), P(130, 168), P(196, 172)] as [CGPoint]).enumerated() { spark(q, 1.6 + CGFloat(k % 2) * 0.6, Col(1, 1, 1, 0.9)) }
    drawEmber(P(112, 106), 6, crisp: true, glowAmount: 0.5); drawEmber(P(208, 106), 6, crisp: true, glowAmount: 0.5)
}
tutorial("tutorial_shards") {
    tutorialBackdrop()
    groundStrip(158)
    withT(64, 160, scale: 0.82) { drawHero("emberScout", frame: -1) }
    for (k, q) in ([P(120, 74), P(108, 60), P(132, 92)] as [CGPoint]).enumerated() { drawRockChip(q, 5, k, hot: true) }
    halo(P(120, 76), 22, K.molten.alpha(0.6))
    for (k, x) in ([138.0, 170, 202] as [CGFloat]).enumerated() { drawHeartShard(P(x, 112 - CGFloat(k % 2) * 8), 11, crisp: true, glowAmount: 0.7) }
    arrow(P(224, 108), P(250, 108), K.hot, 3.6)
    drawLavaHeart(P(282, 106), 22, ow: 2.4)
}

// Badges
begin(120, 120); drawBadge(true); finish("badge_earned")
begin(120, 120); drawBadge(false); finish("badge_locked")

// Panel texture (tileable both ways)
begin(300, 300)
do {
    let W: CGFloat = 300
    fill(rectPath(R(0, 0, W, W)), Col(hex: 0x1A1216))
    var g = Rng(s: 909)
    var blots: [(CGPoint, CGFloat, Bool)] = []
    for _ in 0..<26 { blots.append((P(g.r(0, W), g.r(0, W)), g.r(18, 50), g.next() > 0.5)) }
    var specks: [(CGPoint, CGFloat, Int)] = []
    for _ in 0..<900 { specks.append((P(g.r(0, W), g.r(0, W)), g.r(0.25, 0.8), Int(g.r(0, 10)))) }
    for ox in [-W, 0, W] {
        for oy in [-W, 0, W] {
            for b in blots { softFill(circle(P(b.0.x + ox, b.0.y + oy), b.1), b.2 ? Col(0.35, 0.25, 0.28, 0.12) : Col(0, 0, 0, 0.2), blur: b.1 * 0.6) }
            for s in specks {
                let p = P(s.0.x + ox, s.0.y + oy)
                if p.x < -2 || p.x > W + 2 || p.y < -2 || p.y > W + 2 { continue }
                let col: Col = s.2 == 0 ? K.molten.alpha(0.35) : (s.2 < 4 ? Col(0.6, 0.48, 0.5, 0.14) : Col(0, 0, 0, 0.28))
                fill(circle(p, s.1), col)
            }
        }
    }
}
finish("panel_texture")

// ===================================================================================
// MARK: - Game UI kit (9-slice chrome: corners/borders live only inside the cap insets)
// ===================================================================================

/// Clips drawing to the four corner cap squares so texture never lands in a stretched band.
func cornersOnly(_ w: CGFloat, _ h: CGFloat, l: CGFloat, t: CGFloat, r: CGFloat, b: CGFloat, _ body: () -> Void) {
    let p = CGMutablePath()
    p.addRect(R(0, 0, l, t)); p.addRect(R(w - r, 0, r, t)); p.addRect(R(0, h - b, l, b)); p.addRect(R(w - r, h - b, r, b))
    clipped(p, body)
}
/// Speckled stone grain, only in the corner caps.
func cornerGrain(_ w: CGFloat, _ h: CGFloat, cap: CGFloat, seed: UInt64, within: CGPath, light: Col = Col(0.85, 0.72, 0.72, 0.16), count: Int = 90) {
    var g = Rng(s: seed)
    cornersOnly(w, h, l: cap, t: cap, r: cap, b: cap) {
        clipped(within) {
            for _ in 0..<count {
                let cx = g.next() > 0.5 ? g.r(0, cap) : g.r(w - cap, w)
                let cy = g.next() > 0.5 ? g.r(0, cap) : g.r(h - cap, h)
                fill(circle(P(cx, cy), g.r(0.25, 0.75)), g.next() > 0.45 ? light : Col(0, 0, 0, 0.35))
            }
        }
    }
}
func glowCrack(_ pts: [CGPoint], _ w: CGFloat = 1, alpha: CGFloat = 1) {
    let p = line(pts)
    softStroke(p, K.molten.alpha(0.9 * alpha), w * 2.4, blur: w * 2.2)
    stroke(p, Col(hex: 0x6A1A0E, alpha), w * 1.5)
    stroke(p, K.molten.alpha(alpha), w)
    stroke(p, K.hot.alpha(0.9 * alpha), w * 0.4)
}
/// Short branching crack that fans out from a corner point toward the inside.
func cornerCrack(_ origin: CGPoint, dx: CGFloat, dy: CGFloat, seed: UInt64, len: CGFloat = 9, w: CGFloat = 0.9, alpha: CGFloat = 1) {
    var g = Rng(s: seed)
    var p = origin, pts = [origin]
    for _ in 0..<3 { p = P(p.x + dx * g.r(len * 0.25, len * 0.45), p.y + dy * g.r(len * 0.15, len * 0.4)); pts.append(p) }
    glowCrack(pts, w, alpha: alpha)
    let b = pts[1]
    glowCrack([b, P(b.x + dx * len * 0.15, b.y + dy * len * 0.4)], w * 0.7, alpha: alpha * 0.8)
}

/// Rectangle with chiselled, faceted corners (all facets sit within `c` of each corner; edges stay straight).
func chisel(_ r: CGRect, _ c: CGFloat, seed: UInt64 = 1) -> CGPath {
    var g = Rng(s: seed)
    func j() -> CGFloat { g.r(-0.05, 0.05) * c }
    let x0 = r.minX, y0 = r.minY, x1 = r.maxX, y1 = r.maxY
    let a: CGFloat = 0.1, b: CGFloat = 0.4
    var pts: [CGPoint] = []
    pts += [P(x0, y0 + c), P(x0 + a * c + j(), y0 + b * c + j()), P(x0 + b * c + j(), y0 + a * c + j()), P(x0 + c, y0)]
    pts += [P(x1 - c, y0), P(x1 - b * c + j(), y0 + a * c + j()), P(x1 - a * c + j(), y0 + b * c + j()), P(x1, y0 + c)]
    pts += [P(x1, y1 - c), P(x1 - a * c + j(), y1 - b * c + j()), P(x1 - b * c + j(), y1 - a * c + j()), P(x1 - c, y1)]
    pts += [P(x0 + c, y1), P(x0 + b * c + j(), y1 - a * c + j()), P(x0 + a * c + j(), y1 - b * c + j()), P(x0, y1 - c)]
    return poly(pts)
}

// MARK: Buttons

enum SlabKind { case molten, stone, disabled }

func drawSlabButton(_ kind: SlabKind, pressed: Bool) {
    let w: CGFloat = 240, h: CGFloat = 64, cap: CGFloat = 28
    let outer = pressed ? R(3, 6, 234, 54) : R(3, 2, 234, 58)
    let lip: CGFloat = pressed ? 2.5 : 7
    let outerPath = chisel(outer, 16, seed: 3)
    shadowed(pressed ? 1 : 2.6, pressed ? 1.5 : 3.2, Col(0.02, 0, 0.02, 0.6)) { fill(outerPath, K.ink) }
    // body / lip
    let inner = outer.insetBy(dx: 2.6, dy: 2.6)
    let body = chisel(inner, 13.8, seed: 3)
    let lipCols: [Col]
    switch kind {
    case .molten: lipCols = [Col(hex: 0x4A2A26), Col(hex: 0x2E1A1C), Col(hex: 0x1A0E12)]
    case .stone: lipCols = [Col(hex: 0x3E3236), Col(hex: 0x2A2024), Col(hex: 0x181014)]
    case .disabled: lipCols = [Col(hex: 0x4E4C54), Col(hex: 0x3A3840), Col(hex: 0x2A2830)]
    }
    linearFill(body, lipCols, P(0, inner.minY), P(0, inner.maxY))
    if kind != .disabled { edgeLight(body, K.molten2.alpha(kind == .molten ? 0.6 : 0.4), 0, -2, blur: 1.2) }
    // face
    let face = R(inner.minX, inner.minY, inner.width, inner.height - lip)
    let facePath = chisel(face, 13, seed: 3)
    var cols: [Col]
    var locs: [CGFloat] = [0, 0.25, 0.6, 1]
    switch kind {
    case .molten:
        cols = [Col(1, 0.93, 0.62), K.hot, K.molten2, Col(hex: 0xE2501A)]
    case .stone:
        cols = [Col(hex: 0x7A6A6E), Col(hex: 0x5E5054), Col(hex: 0x4A3E42), Col(hex: 0x3A2E32)]
    case .disabled:
        cols = [Col(hex: 0x8E8C94), Col(hex: 0x76747C), Col(hex: 0x66646C), Col(hex: 0x5A5860)]
        locs = [0, 0.3, 0.7, 1]
    }
    if pressed { cols = cols.map { $0.darker(kind == .molten ? 0.14 : 0.12) } }
    linearFill(facePath, cols, P(0, face.minY), P(0, face.maxY), locs)
    clipped(facePath) {
        switch kind {
        case .molten:
            // cooled crust rim with a glowing seam just inside it
            stroke(facePath, Col(hex: 0x7A2A12), 5.5)
            stroke(chisel(face.insetBy(dx: 2.9, dy: 2.9), 10.4, seed: 3), Col(1, 0.95, 0.7, pressed ? 0.6 : 0.85), 1.1)
            // gloss band (uniform along x, ends inside the caps)
            fill(rr(R(face.minX + 13, face.minY + 4.5, face.width - 26, 6.5), 3.2), Col(1, 1, 0.92, pressed ? 0.18 : 0.38))
            // deep-orange glow at the bottom of the face
            ctx.drawLinearGradient(gradient([Col(0.8, 0.15, 0.05, 0), Col(0.8, 0.15, 0.05, 0.35)]), start: P(0, face.maxY - 12), end: P(0, face.maxY), options: [])
            // dark crust flecks, corners only, hugging the rim
            var g = Rng(s: pressed ? 801 : 800)
            cornersOnly(w, h, l: cap, t: cap, r: cap, b: cap) {
                // cooled crust plates hugging each corner, with hot seams around them
                for (k, q) in [P(face.minX + 9, face.minY + 8), P(face.maxX - 10, face.minY + 9), P(face.minX + 10, face.maxY - 7), P(face.maxX - 9, face.maxY - 8)].enumerated() {
                    for m in 0..<2 {
                        let off = P(q.x + (m == 0 ? 0 : (k % 2 == 0 ? 8 : -8)), q.y + (m == 0 ? 0 : (k < 2 ? -1.5 : 1.5)))
                        let pl = blob(off, m == 0 ? 4.2 : 2.6, n: 6, seed: UInt64(840 + k * 2 + m), jitter: 0.3, sx: 1.5, sy: 0.8, t: 0.5)
                        softStroke(pl, Col(1, 0.95, 0.6, 0.9), 1.4, blur: 1.4)
                        linearFill(pl, [Col(hex: 0x6A2A1A), Col(hex: 0x3A1410)], P(0, off.y - 4), P(0, off.y + 4))
                        edgeLight(pl, K.molten.alpha(0.8), -0.8, -0.8, blur: 0.5)
                    }
                }
                for _ in 0..<20 {
                    let left = g.next() > 0.5, top = g.next() > 0.5
                    let x = left ? face.minX + g.r(3, 20) : face.maxX - g.r(3, 20)
                    let y = top ? face.minY + g.r(3, 7) : face.maxY - g.r(3, 6)
                    fill(blob(P(x, y), g.r(0.5, 1.1), n: 5, seed: UInt64(g.r(1, 9999)), jitter: 0.35, sx: 1.4, sy: 0.9, t: 0.5), Col(hex: 0x5A1A10, 0.7))
                }
            }
        case .stone, .disabled:
            let groove = chisel(face.insetBy(dx: 4.2, dy: 4.2), 9.2, seed: 4)
            stroke(moved(groove, 0.7, 0.7), Col(1, 0.95, 0.95, kind == .stone ? 0.14 : 0.2), 0.9)
            stroke(groove, Col(0, 0, 0, 0.4), 1.1)
            fill(rr(R(face.minX + 13, face.minY + 3, face.width - 26, 4.5), 2.2), Col(1, 1, 1, kind == .stone ? 0.08 : 0.12))
            if kind == .stone {
                let a: CGFloat = pressed ? 0.75 : 1
                cornerCrack(P(face.minX + 1.5, face.minY + 7), dx: 1, dy: 1, seed: 11, len: 13, w: 1.1, alpha: a)
                cornerCrack(P(face.maxX - 1.5, face.minY + 6), dx: -1, dy: 1, seed: 12, len: 12, w: 1.1, alpha: a)
                cornerCrack(P(face.minX + 6, face.maxY - 1.5), dx: 1, dy: -1, seed: 13, len: 9, w: 1, alpha: a)
                cornerCrack(P(face.maxX - 6, face.maxY - 1.5), dx: -1, dy: -1, seed: 14, len: 9, w: 1, alpha: a)
            }
        }
    }
    cornerGrain(w, h, cap: cap, seed: kind == .molten ? 820 : 821, within: kind == .molten ? body : facePath,
                light: kind == .disabled ? Col(0.95, 0.95, 1, 0.22) : Col(0.85, 0.72, 0.72, 0.16), count: kind == .molten ? 40 : 110)
    switch kind {
    case .molten:
        edgeLight(facePath, Col(1, 1, 0.9, 0.7), 1.6, 1.6, blur: 1)
        edgeLight(facePath, K.crimson.alpha(0.45), -1.6, -1.6, blur: 1)
    case .stone:
        edgeLight(facePath, Col(1, 0.94, 0.92, pressed ? 0.18 : 0.3), 2, 2, blur: 1.2)
        edgeLight(facePath, Col(0, 0, 0, 0.35), -2, -2, blur: 1.2)
        edgeLight(facePath, K.molten2.alpha(0.35), -1.2, -1.2, blur: 0.8)
    case .disabled:
        edgeLight(facePath, Col(1, 1, 1, 0.22), 2, 2, blur: 1.2)
        edgeLight(facePath, Col(0, 0, 0, 0.25), -2, -2, blur: 1.2)
    }
    stroke(facePath, K.ink.alpha(0.75), 1.1)
    stroke(outerPath, K.ink, 2.8)
}

func drawRoundButton(pressed: Bool) {
    let c = P(44, pressed ? 44.5 : 43)
    let r: CGFloat = 40
    shadowed(pressed ? 1 : 2.6, pressed ? 1.5 : 3.2, Col(0.02, 0, 0.02, 0.6)) { fill(circle(P(44, 44.5), r), K.ink) }
    // lip (side of the medallion)
    let lip = circle(P(44, 44.5 + (pressed ? 0 : 0)), r - 2.6)
    linearFill(lip, [Col(hex: 0x3E3236), Col(hex: 0x1A1014)], P(0, 6), P(0, 82))
    edgeLight(lip, K.molten2.alpha(0.45), 0, -2, blur: 1)
    // rim top
    let rimTop = circle(P(c.x, c.y - (pressed ? 0.5 : 2.5)), r - 2.6)
    let tc = P(c.x, c.y - (pressed ? 0.5 : 2.5))
    linearFill(rimTop, [Col(hex: 0x7A6A6E).darker(pressed ? 0.12 : 0), Col(hex: 0x56484C).darker(pressed ? 0.12 : 0), Col(hex: 0x3A2E32)], P(tc.x - r, tc.y - r), P(tc.x + r, tc.y + r))
    edgeLight(rimTop, Col(1, 0.94, 0.92, pressed ? 0.18 : 0.32), 2, 2, blur: 1.2)
    edgeLight(rimTop, K.molten2.alpha(0.5), -1.8, -1.8, blur: 1)
    // carved notches around the rim
    for i in 0..<12 {
        let a = CGFloat(i) / 12 * .pi * 2 + .pi / 12
        let p1 = polar(tc, r - 6.5, a), p2 = polar(tc, r - 10, a)
        stroke(line([p1, p2]), Col(0, 0, 0, 0.45), 1.4)
        stroke(moved(line([p1, p2]), 0.6, 0.6), Col(1, 0.95, 0.9, 0.12), 0.7)
    }
    var g = Rng(s: pressed ? 31 : 30)
    clipped(rimTop) { for _ in 0..<70 { fill(circle(polar(tc, g.r(28, 38), g.r(0, .pi * 2)), g.r(0.25, 0.7)), g.next() > 0.5 ? Col(0.85, 0.72, 0.72, 0.16) : Col(0, 0, 0, 0.35)) } }
    stroke(rimTop, K.ink.alpha(0.7), 1.1)
    // recessed empty centre
    let well = circle(tc, 26.5)
    stroke(circle(tc, 27.6), Col(1, 0.95, 0.9, 0.16), 1.2)
    linearFill(well, [Col(hex: 0x120A0E), Col(hex: 0x1E1418), Col(hex: 0x2A1E22)], P(0, tc.y - 26), P(0, tc.y + 26))
    edgeLight(well, Col(0, 0, 0, pressed ? 0.8 : 0.65), 3, 3.5, blur: 2.5)
    edgeLight(well, K.molten.alpha(pressed ? 0.45 : 0.3), -1.4, -1.6, blur: 1.2)
    stroke(well, K.ink, 1.8)
    stroke(circle(P(44, 44.5), r), K.ink, 2.8)
}

// MARK: Panels

/// Carved basalt tablet. Corners/nubs/grain stay inside `cap`; the border bands are uniform along their length.
func drawTablet(_ w: CGFloat, _ h: CGFloat, cap: CGFloat, lava: Bool) {
    let outer = R(2, 2, w - 4, h - 5)
    let outerPath = chisel(outer, 17, seed: 7)
    shadowed(2.4, 3, Col(0.02, 0, 0.02, 0.6)) { fill(outerPath, K.ink) }
    let slab = chisel(outer.insetBy(dx: 2.6, dy: 2.6), 15, seed: 7)
    linearFill(slab, [Col(hex: 0x5E4E52), Col(hex: 0x463A3E), Col(hex: 0x30262A)], P(0, outer.minY), P(0, outer.maxY))
    edgeLight(slab, Col(1, 0.94, 0.92, 0.28), 2.2, 2.2, blur: 1.4)
    edgeLight(slab, lava ? K.molten.alpha(0.75) : K.molten2.alpha(0.4), -2, -2, blur: 1.4)
    cornerGrain(w, h, cap: cap, seed: lava ? 51 : 50, within: slab, count: 160)
    // outer chiselled groove
    let g1 = chisel(R(9, 9, w - 18, h - 21), 11.5, seed: 8)
    if lava {
        softStroke(g1, K.molten.alpha(0.95), 3, blur: 3)
        stroke(g1, Col(hex: 0x5A160C), 2.4); stroke(g1, K.molten, 1.5); stroke(g1, K.hot, 0.6)
    } else {
        stroke(moved(g1, 0.8, 0.8), Col(1, 0.95, 0.92, 0.14), 1)
        stroke(g1, Col(0, 0, 0, 0.5), 1.5)
    }
    // inner field with a second groove and soft inner shadow
    let fieldR = R(17, 17, w - 34, h - 37)
    let field = chisel(fieldR, 7, seed: 9)
    let g2 = chisel(fieldR.insetBy(dx: -2.4, dy: -2.4), 8.5, seed: 9)
    stroke(moved(g2, 0.7, 0.7), Col(1, 0.95, 0.92, 0.12), 0.9)
    stroke(g2, lava ? K.molten.alpha(0.55) : Col(0, 0, 0, 0.5), 1.2)
    linearFill(field, [Col(hex: 0x150C10), Col(hex: 0x1A1014), Col(hex: 0x1C1216)], P(0, fieldR.minY), P(0, fieldR.maxY))
    edgeLight(field, Col(0, 0, 0, 0.75), 3.5, 3.5, blur: 3)
    edgeLight(field, (lava ? K.molten : Col(1, 0.9, 0.9, 1)).alpha(lava ? 0.3 : 0.06), -1.5, -1.5, blur: 1.5)
    stroke(field, K.ink, 1.4)
    // rune nubs on the groove corners
    for (i, q) in [P(13, 13), P(w - 13, 13), P(13, h - 16), P(w - 13, h - 16)].enumerated() {
        if lava { halo(q, 7, K.molten.alpha(0.8)) }
        let nub = circle(q, 3.6)
        fill(moved(nub, 0.5, 0.9), Col(0, 0, 0, 0.5))
        if lava { radialFill(nub, [Col(1, 0.97, 0.8), K.hot, K.molten], P(q.x - 1, q.y - 1), 4.4) } else { radialFill(nub, [Col(hex: 0x8A7A7E), Col(hex: 0x56484C), Col(hex: 0x30262A)], P(q.x - 1.2, q.y - 1.2), 4.6) }
        stroke(nub, K.ink, 1)
        // tiny carved rune tick beside each nub
        let dx: CGFloat = i % 2 == 0 ? 1 : -1, dy: CGFloat = i < 2 ? 1 : -1
        stroke(line([P(q.x + dx * 6.5, q.y), P(q.x + dx * 9.5, q.y)]), lava ? K.hot.alpha(0.8) : Col(0, 0, 0, 0.45), 0.9)
        stroke(line([P(q.x, q.y + dy * 6.5), P(q.x, q.y + dy * 9.5)]), lava ? K.hot.alpha(0.8) : Col(0, 0, 0, 0.45), 0.9)
    }
    if lava {
        cornerCrack(P(5, 26), dx: 1, dy: 1, seed: 61, len: 8, w: 0.8)
        cornerCrack(P(w - 5, h - 30), dx: -1, dy: 1, seed: 62, len: 8, w: 0.8)
    }
    stroke(outerPath, K.ink, 2.8)
}

func drawPlaque() {
    let w: CGFloat = 320, h: CGFloat = 96
    // obsidian body: uniform along x between the end caps
    let body = R(36, 26, 248, 44)
    let bodyPath = rectPath(body)
    shadowed(2, 3, Col(0.02, 0, 0.02, 0.6)) { fill(rectPath(body.insetBy(dx: 0, dy: -2.6)), K.ink) }
    linearFill(bodyPath, [Col(hex: 0x3A2A40), Col(hex: 0x1A1020), Col(hex: 0x0E0812), Col(hex: 0x1A0E14)], P(0, body.minY), P(0, body.maxY), [0, 0.3, 0.75, 1])
    fill(rectPath(R(body.minX, body.minY + 3, body.width, 4)), Col(1, 0.95, 1, 0.14))
    // molten trim rails top and bottom
    for y in [body.minY + 0.5, body.maxY - 0.5] {
        let rail = line([P(body.minX, y), P(body.maxX, y)])
        stroke(rail, K.ink, 5.2)
        stroke(rail, K.gold.darker(0.25), 2.6)
        stroke(moved(rail, 0, -0.5), K.hot.alpha(0.8), 0.8)
    }
    stroke(line([P(body.minX, body.maxY - 4), P(body.maxX, body.maxY - 4)]), K.molten.alpha(0.35), 0.8)
    // ornate end caps with flame finials
    for side in [-1.0, 1.0] as [CGFloat] {
        let ex: (CGFloat) -> CGFloat = { side < 0 ? $0 : w - $0 }
        // flame finial pointing outward-up
        halo(P(ex(13), 30), 14, K.molten.alpha(0.7))
        withT(ex(14), 40, rot: side * -0.5) { drawFlame(P(0, 0), 10, 22, lean: side * -1.5, ow: 1.6) }
        let cap = poly([P(ex(58), 16), P(ex(28), 16), P(ex(12), 48), P(ex(28), 80), P(ex(58), 80), P(ex(50), 48)])
        shadowed(2, 3, Col(0.02, 0, 0.02, 0.6)) { fill(cap, K.ink) }
        paint(cap, Col(hex: 0x56484C), ow: 0, rim: 0.6)
        let inset = poly([P(ex(52), 22), P(ex(31), 22), P(ex(18.5), 48), P(ex(31), 74), P(ex(52), 74), P(ex(45), 48)])
        stroke(moved(inset, 0.7, 0.7), Col(1, 0.95, 0.92, 0.14), 0.9)
        stroke(inset, Col(0, 0, 0, 0.5), 1.3)
        // glowing gem in the cap
        let gem = poly([P(ex(36), 38), P(ex(42), 48), P(ex(36), 58), P(ex(30), 48)])
        halo(P(ex(36), 48), 10, K.molten.alpha(0.8))
        linearFill(gem, [Col(1, 0.97, 0.8), K.hot, K.molten, K.crimson], P(ex(30), 38), P(ex(42), 58))
        fill(poly([P(ex(36), 38), P(ex(36), 48), P(ex(30), 48)]), Col(1, 1, 1, 0.35))
        stroke(gem, K.ink, 1.2)
        var g = Rng(s: side < 0 ? 71 : 72)
        clipped(cap) { for _ in 0..<45 { fill(circle(P(ex(g.r(12, 58)), g.r(16, 80)), g.r(0.25, 0.7)), g.next() > 0.5 ? Col(0.85, 0.72, 0.72, 0.16) : Col(0, 0, 0, 0.35)) } }
        cornerCrack(P(ex(56), 78), dx: -side, dy: -1, seed: side < 0 ? 73 : 74, len: 7, w: 0.8)
        stroke(cap, K.ink, 2.6)
    }
}

func drawToast() {
    let r = R(2, 3, 296, 55)
    let p = chisel(r, 14, seed: 12)
    shadowed(2.2, 3, Col(0.02, 0, 0.02, 0.6)) { fill(p, K.ink) }
    let s = chisel(r.insetBy(dx: 2.5, dy: 2.5), 12, seed: 12)
    linearFill(s, [Col(hex: 0x3A2E32), Col(hex: 0x241A1E), Col(hex: 0x1A1014)], P(0, r.minY), P(0, r.maxY))
    edgeLight(s, Col(1, 0.94, 0.92, 0.2), 1.8, 1.8, blur: 1.2)
    // lava-lit bottom edge
    edgeLight(s, K.molten.alpha(0.85), 0, -3.2, blur: 1.8)
    clipped(s) { stroke(line([P(r.minX + 12, r.maxY - 3.6), P(r.maxX - 12, r.maxY - 3.6)]), K.hot.alpha(0.65), 0.9) }
    let groove = chisel(r.insetBy(dx: 7, dy: 7), 7.5, seed: 13)
    stroke(moved(groove, 0.6, 0.6), Col(1, 0.95, 0.92, 0.1), 0.8)
    stroke(groove, Col(0, 0, 0, 0.45), 1.1)
    cornerGrain(300, 64, cap: 30, seed: 90, within: s, count: 80)
    cornerCrack(P(r.minX + 3, r.maxY - 4), dx: 1, dy: -1, seed: 91, len: 7, w: 0.8)
    cornerCrack(P(r.maxX - 3, r.maxY - 4), dx: -1, dy: -1, seed: 92, len: 7, w: 0.8)
    stroke(p, K.ink, 2.6)
}

func drawChip() {
    let r = R(2, 3, 116, 33)
    let p = rr(r, 16.5)
    shadowed(1.8, 2.4, Col(0.02, 0, 0.02, 0.6)) { fill(p, K.ink) }
    let s = rr(r.insetBy(dx: 2.3, dy: 2.3), 14.2)
    linearFill(s, [Col(hex: 0x5E5054), Col(hex: 0x40343A), Col(hex: 0x2A2024)], P(0, r.minY), P(0, r.maxY))
    fill(rr(R(r.minX + 12, r.minY + 4.5, r.width - 24, 4), 2), Col(1, 1, 1, 0.1))
    edgeLight(s, Col(1, 0.94, 0.92, 0.28), 1.8, 1.8, blur: 1)
    edgeLight(s, K.molten2.alpha(0.5), -1.6, -1.6, blur: 1)
    cornerGrain(120, 40, cap: 20, seed: 95, within: s, count: 50)
    stroke(p, K.ink, 2.4)
}

func drawSocket(full: Bool) {
    let c = P(14, 14)
    fill(circle(P(14, 14.8), 12.4), K.ink)
    let ring = circle(c, 11)
    linearFill(ring, [Col(hex: 0x6E5E62), Col(hex: 0x46393E), Col(hex: 0x2A2024)], P(3, 3), P(25, 25))
    edgeLight(ring, K.molten2.alpha(0.45), -1, -1, blur: 0.6)
    let well = circle(c, 7.2)
    if full {
        halo(c, 12, K.molten.alpha(0.6))
        radialFill(well, [Col(1, 0.98, 0.85), K.hot, K.molten, Col(hex: 0xB8301A)], P(c.x - 1.8, c.y - 1.8), 9.5, [0, 0.3, 0.7, 1])
        fill(ellipse(R(c.x - 4.2, c.y - 5, 3.6, 2.4)), Col(1, 1, 1, 0.75))
        edgeLight(well, K.crimson.alpha(0.5), -1, -1, blur: 0.6)
    } else {
        linearFill(well, [Col(hex: 0x0E080C), Col(hex: 0x241A1E)], P(0, c.y - 7), P(0, c.y + 7))
        edgeLight(well, Col(0, 0, 0, 0.7), 1.6, 1.6, blur: 1.2)
        edgeLight(well, Col(1, 0.9, 0.9, 0.12), -0.8, -0.8)
    }
    stroke(well, K.ink, 1.1)
    stroke(circle(c, 12.2), K.ink, 1.6)
}

func drawBarFrame() {
    let r = R(1.5, 1.5, 237, 24.5)
    let p = rr(r, 12.2)
    shadowed(1.4, 2, Col(0.02, 0, 0.02, 0.6)) { fill(p, K.ink) }
    let s = rr(r.insetBy(dx: 2.2, dy: 2.2), 10)
    linearFill(s, [Col(hex: 0x5E5054), Col(hex: 0x40343A), Col(hex: 0x2A2024)], P(0, r.minY), P(0, r.maxY))
    edgeLight(s, Col(1, 0.94, 0.92, 0.26), 1.5, 1.5, blur: 1)
    edgeLight(s, K.molten2.alpha(0.45), -1.4, -1.4, blur: 1)
    let trough = rr(R(6, 6.5, 228, 14.5), 7.2)
    stroke(moved(trough, 0.6, 0.8), Col(1, 0.95, 0.92, 0.18), 1)
    linearFill(trough, [Col(hex: 0x0C060A), Col(hex: 0x1C1216)], P(0, 6.5), P(0, 21))
    edgeLight(trough, Col(0, 0, 0, 0.7), 2, 2.4, blur: 1.6)
    stroke(trough, K.ink, 1.2)
    stroke(p, K.ink, 2.2)
}

func drawBarFill() {
    let r = R(1, 1, 238, 18)
    let p = rr(r, 9)
    linearFill(p, [Col(1, 0.95, 0.7), K.hot, K.molten2, K.molten, Col(hex: 0xC2341A)], P(0, r.minY), P(0, r.maxY), [0, 0.15, 0.45, 0.75, 1])
    fill(rr(R(8, 3.2, 224, 3.6), 1.8), Col(1, 1, 0.95, 0.6))
    edgeLight(p, Col(0.55, 0.06, 0.04, 0.6), -1.2, -1.8, blur: 1)
    stroke(p, Col(hex: 0x6A1A0E), 1.3)
}

func drawDivider() {
    let c = P(160, 12)
    // tapered basalt line
    for side in [-1.0, 1.0] as [CGFloat] {
        let pts = [P(c.x + side * 13, c.y - 3), P(c.x + side * 70, c.y - 1.6), P(c.x + side * 150, c.y - 0.6), P(c.x + side * 150, c.y + 0.6), P(c.x + side * 70, c.y + 1.6), P(c.x + side * 13, c.y + 3)]
        let bar = poly(pts)
        stroke(bar, K.ink, 2.4)
        linearFill(bar, [Col(hex: 0x8A7A7E), Col(hex: 0x56484C), Col(hex: 0x2E2428)], P(0, c.y - 3), P(0, c.y + 3))
        edgeLight(bar, K.molten.alpha(0.7), 0, -1, blur: 0.5)
        stroke(line([P(c.x + side * 16, c.y + 0.9), P(c.x + side * 120, c.y + 0.3)]), K.molten.alpha(0.6), 0.6)
        let dot = circle(P(c.x + side * 152, c.y), 1.8)
        fill(dot, K.ink); fill(circle(P(c.x + side * 152, c.y), 1.0), K.molten)
        // small diamonds partway along
        let dq = P(c.x + side * 60, c.y)
        let d = poly([P(dq.x, dq.y - 4.5), P(dq.x + 3.4, dq.y), P(dq.x, dq.y + 4.5), P(dq.x - 3.4, dq.y)])
        stroke(d, K.ink, 2); linearFill(d, [K.hot, K.molten, K.crimson], P(dq.x, dq.y - 4.5), P(dq.x, dq.y + 4.5)); halo(dq, 6, K.molten.alpha(0.5))
    }
    halo(P(c.x, c.y - 2), 16, K.molten.alpha(0.7))
    drawFlame(P(c.x, c.y - 0.5), 11, 12.5, lean: 0.6, ow: 1.2)
    let gem = poly([P(c.x, c.y - 3), P(c.x + 6, c.y + 3.5), P(c.x, c.y + 10.5), P(c.x - 6, c.y + 3.5)])
    linearFill(gem, [Col(1, 0.75, 0.8), K.crimson, Col(hex: 0x6A0A1E)], P(c.x - 6, c.y - 3), P(c.x + 6, c.y + 10.5))
    fill(poly([P(c.x, c.y - 3), P(c.x, c.y + 3.5), P(c.x - 6, c.y + 3.5)]), Col(1, 1, 1, 0.35))
    stroke(gem, K.ink, 1.2)
}

func drawPedestal() {
    let c = P(130, 36), rx: CGFloat = 120, ry: CGFloat = 28, depth: CGFloat = 22
    var top: [CGPoint] = []
    for i in 0..<6 { let a = CGFloat(i) / 6 * .pi * 2; top.append(P(c.x + cos(a) * rx, c.y + sin(a) * ry)) }
    // top[0]=right, [1]=front-right, [2]=front-left, [3]=left, [4]=back-left, [5]=back-right
    let down = { (p: CGPoint) in P(p.x, p.y + depth) }
    halo(P(130, 70), 110, K.molten.alpha(0.35))
    fill(ellipse(R(12, 70, 236, 18)), Col(0, 0, 0, 0.45))
    let sideL = poly([top[3], top[2], down(top[2]), down(top[3])])
    let sideF = poly([top[2], top[1], down(top[1]), down(top[2])])
    let sideR = poly([top[1], top[0], down(top[0]), down(top[1])])
    linearFill(sideL, [Col(hex: 0x4A3E42), Col(hex: 0x2E2428)], P(0, top[3].y), P(0, down(top[2]).y))
    linearFill(sideF, [Col(hex: 0x3A2E32), Col(hex: 0x221A1E)], P(0, top[2].y), P(0, down(top[2]).y))
    linearFill(sideR, [Col(hex: 0x2A2024), Col(hex: 0x16100E)], P(0, top[0].y), P(0, down(top[1]).y))
    edgeLight(sideR, K.molten.alpha(0.6), -3, 0, blur: 2)
    // strata on sides
    for s in [sideL, sideF, sideR] {
        clipped(s) {
            for k in 0..<2 { let y = c.y + ry + 7 + CGFloat(k) * 7; stroke(line([P(0, y - 10), P(260, y + 6)]), Col(0, 0, 0, 0.3), 0.9) }
        }
    }
    // cracks with lava seeping on the sides
    glowCrack([P(96, 66), P(100, 74), P(97, 81), P(101, 86)], 1.2)
    glowCrack([P(176, 64), P(172, 72), P(178, 79)], 1.1)
    glowCrack([P(40, 56), P(44, 63), P(41, 70)], 0.9)
    for s in [sideL, sideF, sideR] { stroke(s, K.ink, 2) }
    // top face
    let topPath = poly(top)
    linearFill(topPath, [Col(hex: 0x6E5E62), Col(hex: 0x54464A), Col(hex: 0x3E3236)], P(c.x - rx * 0.6, c.y - ry), P(c.x + rx * 0.6, c.y + ry))
    var inner: [CGPoint] = []
    for p in top { inner.append(P(c.x + (p.x - c.x) * 0.84, c.y + (p.y - c.y) * 0.8)) }
    let innerPath = poly(inner)
    stroke(moved(innerPath, 0.8, 0.8), Col(1, 0.95, 0.92, 0.14), 1)
    stroke(innerPath, Col(0, 0, 0, 0.45), 1.5)
    var g = Rng(s: 55)
    clipped(topPath) {
        for _ in 0..<180 { fill(circle(P(g.r(10, 250), g.r(8, 64)), g.r(0.25, 0.8)), g.next() > 0.5 ? Col(0.85, 0.72, 0.72, 0.16) : Col(0, 0, 0, 0.3)) }
        glowCrack([P(26, 34), P(40, 38), P(48, 34), P(58, 40)], 1.1)
        glowCrack([P(210, 22), P(198, 28), P(206, 34), P(194, 40)], 1.1)
        glowCrack([P(150, 58), P(156, 52), P(170, 54)], 0.9)
    }
    edgeLight(topPath, Col(1, 0.94, 0.92, 0.3), 2.5, 2.5, blur: 1.5)
    edgeLight(topPath, K.molten2.alpha(0.55), -2.2, -2.2, blur: 1.4)
    stroke(topPath, K.ink, 2.4)
}

func tabletShape(_ inset: CGFloat) -> CGPath {
    let i = inset
    let p = CGMutablePath()
    p.move(to: P(10 + i, 158 - i))
    p.addLine(to: P(9 + i, 34 + i * 0.6))
    appendSmooth(p, [P(9 + i, 34 + i * 0.6), P(30 + i * 0.6, 17 + i), P(62, 9 + i), P(96, 11 + i), P(124 - i * 0.6, 19 + i), P(141 - i, 36 + i * 0.6)], 0.9)
    p.addLine(to: P(140 - i, 158 - i))
    p.closeSubpath()
    return p
}

func drawMenuTablet() {
    // base plinth
    fill(ellipse(R(8, 156, 134, 12)), Col(0, 0, 0, 0.45))
    let plinth = rr(R(4, 150, 142, 16), 4)
    shadowed(1.5, 2) { paint(plinth, Col(hex: 0x3A2E32), ow: 2.4, rim: 0.7) }
    stroke(plinth, K.ink, 2.4)
    let body = tabletShape(0)
    shadowed(2.4, 3, Col(0.02, 0, 0.02, 0.6)) { fill(body, K.ink) }
    linearFill(body, [Col(hex: 0x6A5A5E), Col(hex: 0x4E4044), Col(hex: 0x3A2E32)], P(0, 9), P(0, 158))
    var g = Rng(s: 66)
    clipped(body) {
        for _ in 0..<260 {
            let p = P(g.r(8, 142), g.r(8, 158))
            if p.x > 30 && p.x < 120 && p.y > 30 && p.y < 140 { continue }
            fill(circle(p, g.r(0.25, 0.8)), g.next() > 0.5 ? Col(0.85, 0.72, 0.72, 0.16) : Col(0, 0, 0, 0.32))
        }
    }
    edgeLight(body, Col(1, 0.94, 0.92, 0.3), 2.5, 2.5, blur: 1.5)
    edgeLight(body, K.molten2.alpha(0.55), -2.4, -2.4, blur: 1.4)
    // carved frame
    let frame = tabletShape(8)
    stroke(moved(frame, 0.8, 0.8), Col(1, 0.95, 0.92, 0.15), 1)
    stroke(frame, Col(0, 0, 0, 0.5), 1.6)
    // icon field (upper ~60%), plain and slightly recessed
    let field = tabletShape(13)
    clipped(field) {
        linearFill(rectPath(R(0, 0, 150, 170)), [Col(hex: 0x3A2E32), Col(hex: 0x2E2428)], P(0, 20), P(0, 118))
    }
    edgeLight(field, Col(0, 0, 0, 0.55), 2.5, 2.5, blur: 2)
    // darker label band (bottom ~30%)
    let label = rr(R(22, 112, 106, 30), 5)
    linearFill(label, [Col(hex: 0x150C10), Col(hex: 0x1C1216)], P(0, 112), P(0, 142))
    edgeLight(label, Col(0, 0, 0, 0.7), 2.4, 2.4, blur: 2)
    edgeLight(label, Col(1, 0.9, 0.9, 0.08), -1, -1)
    stroke(label, K.ink, 1.3)
    stroke(line([P(26, 108), P(124, 108)]), Col(0, 0, 0, 0.45), 1)
    stroke(line([P(26, 109), P(124, 109)]), Col(1, 0.95, 0.92, 0.12), 0.8)
    // lava crack at the base
    glowCrack([P(98, 158), P(104, 152), P(101, 146), P(108, 143)], 1.3)
    glowCrack([P(104, 152), P(112, 154)], 0.9)
    glowCrack([P(30, 158), P(27, 152), P(32, 148)], 1.0)
    halo(P(102, 158), 16, K.molten.alpha(0.5))
    stroke(body, K.ink, 2.8)
}

func drawEmberCounter() {
    let cap = R(22, 10, 156, 38)
    let p = rr(cap, 19)
    shadowed(2, 2.6, Col(0.02, 0, 0.02, 0.6)) { fill(p, K.ink) }
    let s = rr(cap.insetBy(dx: 2.5, dy: 2.5), 16.5)
    linearFill(s, [Col(hex: 0x3E3236), Col(hex: 0x241A1E), Col(hex: 0x1A1014)], P(0, cap.minY), P(0, cap.maxY))
    edgeLight(s, Col(1, 0.94, 0.92, 0.2), 1.6, 1.6, blur: 1)
    edgeLight(s, K.molten.alpha(0.6), -1.5, -2, blur: 1.2)
    let well = rr(R(48, 16.5, 124, 25), 12.5)
    linearFill(well, [Col(hex: 0x0E080C), Col(hex: 0x1A1014)], P(0, 16), P(0, 42))
    edgeLight(well, Col(0, 0, 0, 0.7), 2, 2.4, blur: 1.6)
    stroke(moved(well, 0.5, 0.7), Col(1, 0.95, 0.92, 0.12), 0.8)
    stroke(well, K.ink, 1.1)
    stroke(p, K.ink, 2.6)
    // brazier bowl on the left end
    halo(P(25, 20), 24, K.molten.alpha(0.6))
    drawFlame(P(22, 26), 14, 20, lean: 1.5, ow: 1.4)
    drawFlame(P(30, 26), 9, 13, lean: 1, ow: 1.2)
    let bowl = CGMutablePath()
    bowl.move(to: P(3, 25)); bowl.addLine(to: P(47, 25))
    bowl.addCurve(to: P(32, 43), control1: P(47, 35), control2: P(41, 42))
    bowl.addLine(to: P(18, 43)); bowl.addCurve(to: P(3, 25), control1: P(9, 42), control2: P(3, 35)); bowl.closeSubpath()
    let stand = poly([P(18, 42), P(32, 42), P(36, 51), P(14, 51)])
    paint(stand, Col(hex: 0x3A2E32), ow: 2, rim: 0.6)
    paint(bowl, Col(hex: 0x5A4A4E), ow: 2.4, rim: 0.7)
    clipped(bowl) { stroke(line([P(3, 31), P(47, 31)]), Col(0, 0, 0, 0.35), 1); glowCrack([P(12, 27), P(15, 33), P(12, 38)], 0.8) }
    let lip = ellipse(R(1.5, 21.5, 47, 7))
    paint(lip, Col(hex: 0x6A5A5E), ow: 2, rim: 0.3)
    let coals = ellipse(R(5, 22.8, 40, 4.4))
    linearFill(coals, [K.hot, K.molten], P(0, 23), P(0, 27))
    for x in [11.0, 19, 27, 36] as [CGFloat] { fill(circle(P(x, 24.6), 1.3), Col(hex: 0x5A1A10, 0.8)) }
    spark(P(14, 6), 0.9); spark(P(34, 9), 0.7)
}

func drawStele() {
    let w: CGFloat = 340, h: CGFloat = 480
    // plinth
    let plinth = rr(R(6, 440, 328, 36), 6)
    shadowed(2.4, 3, Col(0.02, 0, 0.02, 0.6)) { fill(plinth, K.ink) }
    paint(plinth, Col(hex: 0x3A2E32), ow: 0, rim: 0.7)
    stroke(line([P(14, 448), P(326, 448)]), Col(1, 0.95, 0.92, 0.14), 1)
    stroke(plinth, K.ink, 2.8)
    // obsidian body with arched top
    func archBody(_ i: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: P(20 + i, 442))
        p.addLine(to: P(20 + i, 118))
        p.addCurve(to: P(w / 2, 12 + i), control1: P(20 + i, 50 + i * 0.4), control2: P(90 + i * 0.4, 12 + i))
        p.addCurve(to: P(w - 20 - i, 118), control1: P(w - 90 - i * 0.4, 12 + i), control2: P(w - 20 - i, 50 + i * 0.4))
        p.addLine(to: P(w - 20 - i, 442))
        p.closeSubpath()
        return p
    }
    let body = archBody(0)
    shadowed(2.4, 3.5, Col(0.02, 0, 0.02, 0.6)) { fill(body, K.ink) }
    linearFill(body, [Col(hex: 0x3A2A40), Col(hex: 0x21162A), Col(hex: 0x150C18), Col(hex: 0x120A12)], P(0, 12), P(0, 442), [0, 0.15, 0.5, 1])
    // glossy vertical sheen bands (uniform along y in the side caps)
    clipped(body) {
        fill(rectPath(R(30, 0, 6, h)), Col(1, 0.95, 1, 0.08))
        fill(rectPath(R(40, 0, 2, h)), Col(1, 0.95, 1, 0.08))
    }
    edgeLight(body, Col(1, 0.94, 1, 0.24), 2.4, 2.4, blur: 1.5)
    edgeLight(body, K.molten.alpha(0.7), -2.6, -2.6, blur: 1.6)
    // carved frame (arch groove)
    let frame = archBody(10)
    stroke(moved(frame, 0.8, 0.8), Col(1, 0.95, 1, 0.13), 1)
    stroke(frame, Col(0, 0, 0, 0.6), 1.8)
    // arch tympanum with volcano relief
    let tymp = CGMutablePath()
    tymp.move(to: P(36, 104))
    tymp.addCurve(to: P(w / 2, 30), control1: P(36, 62), control2: P(100, 30))
    tymp.addCurve(to: P(w - 36, 104), control1: P(w - 100, 30), control2: P(w - 36, 62))
    tymp.closeSubpath()
    linearFill(tymp, [Col(hex: 0x2A1E30), Col(hex: 0x1A1020)], P(0, 30), P(0, 104))
    edgeLight(tymp, Col(0, 0, 0, 0.6), 2.5, 2.5, blur: 2)
    clipped(tymp) {
        halo(P(w / 2, 58), 40, K.molten.alpha(0.55))
        let v = smoothClosed([P(w / 2 - 70, 108), P(w / 2 - 34, 82), P(w / 2 - 12, 58), P(w / 2 + 12, 58), P(w / 2 + 34, 82), P(w / 2 + 70, 108)], 0.4)
        linearFill(v, [Col(hex: 0x6A5662), Col(hex: 0x3A2A34), Col(hex: 0x24161E)], P(w / 2 - 40, 58), P(w / 2 + 40, 108))
        edgeLight(v, Col(1, 0.94, 1, 0.22), 1.6, 1.6, blur: 1)
        edgeLight(v, K.molten.alpha(0.6), -1.6, -1.6, blur: 1)
        stroke(v, K.ink, 1.4)
        fill(ellipse(R(w / 2 - 11, 56, 22, 4.5)), K.hot)
        glowCrack([P(w / 2 - 4, 60), P(w / 2 - 9, 72), P(w / 2 - 4, 84), P(w / 2 - 12, 100)], 1.2)
        glowCrack([P(w / 2 + 5, 60), P(w / 2 + 12, 74), P(w / 2 + 9, 90), P(w / 2 + 18, 104)], 1.1)
        drawFlame(P(w / 2, 58), 12, 20, lean: 1.2, ow: 1.2)
        for q in [P(w / 2 - 22, 44), P(w / 2 + 24, 40), P(w / 2 + 6, 34)] { spark(q, 0.9) }
        // carved sun-rays behind the relief
        for k in 0..<7 {
            let a = -CGFloat.pi + CGFloat(k + 1) / 8 * .pi
            stroke(line([polar(P(w / 2, 60), 48, a), polar(P(w / 2, 60), 70, a)]), Col(0, 0, 0, 0.35), 1.2)
        }
    }
    stroke(tymp, K.ink, 1.6)
    // lintel line under the arch
    stroke(line([P(36, 108), P(w - 36, 108)]), Col(0, 0, 0, 0.55), 1.6)
    stroke(line([P(36, 109.4), P(w - 36, 109.4)]), K.molten.alpha(0.4), 0.8)
    // calm dark centre field
    let field = rr(R(38, 114, w - 76, 292), 4)
    fill(field, Col(hex: 0x0E080E))
    edgeLight(field, Col(0, 0, 0, 0.75), 3.5, 3.5, blur: 3)
    edgeLight(field, K.molten.alpha(0.12), -1.5, -1.5, blur: 1.5)
    stroke(field, K.ink, 1.4)
    // glowing cracks in the cap corners only
    cornerCrack(P(22, 70), dx: 1, dy: 1, seed: 101, len: 14, w: 1)
    cornerCrack(P(w - 22, 82), dx: -1, dy: 1, seed: 102, len: 12, w: 1)
    cornerCrack(P(22, 440), dx: 1, dy: -1, seed: 103, len: 14, w: 1.1)
    cornerCrack(P(w - 22, 440), dx: -1, dy: -1, seed: 104, len: 12, w: 1.1)
    glowCrack([P(60, 30), P(66, 36), P(64, 44)], 0.8)
    glowCrack([P(w - 62, 32), P(w - 68, 38)], 0.8)
    // rune nubs on the bottom corners
    for q in [P(30, 424), P(w - 30, 424)] {
        let nub = circle(q, 4)
        radialFill(nub, [Col(1, 0.97, 0.8), K.hot, K.molten], P(q.x - 1, q.y - 1), 5)
        halo(q, 9, K.molten.alpha(0.6))
        stroke(nub, K.ink, 1.1)
    }
    stroke(body, K.ink, 3)
}

// MARK: UI kit generation

begin(240, 64); drawSlabButton(.molten, pressed: false); finish("btn_molten")
begin(240, 64); drawSlabButton(.molten, pressed: true); finish("btn_molten_pressed")
begin(240, 64); drawSlabButton(.stone, pressed: false); finish("btn_stone")
begin(240, 64); drawSlabButton(.stone, pressed: true); finish("btn_stone_pressed")
begin(240, 64); drawSlabButton(.disabled, pressed: false); finish("btn_disabled")
begin(88, 88); drawRoundButton(pressed: false); finish("btn_round")
begin(88, 88); drawRoundButton(pressed: true); finish("btn_round_pressed")
begin(300, 200); drawTablet(300, 200, cap: 40, lava: false); finish("panel_stone")
begin(300, 200); drawTablet(300, 200, cap: 40, lava: true); finish("panel_lava")
begin(320, 96); drawPlaque(); finish("panel_plaque")
begin(300, 64); drawToast(); finish("panel_toast")
begin(120, 40); drawChip(); finish("chip_stone")
begin(28, 28); drawSocket(full: false); finish("socket_empty")
begin(28, 28); drawSocket(full: true); finish("socket_full")
begin(240, 28); drawBarFrame(); finish("bar_frame")
begin(240, 20); drawBarFill(); finish("bar_fill")
begin(320, 24); drawDivider(); finish("divider_flame")
begin(260, 90); drawPedestal(); finish("pedestal")
begin(150, 170); drawMenuTablet(); finish("menu_tablet")
begin(180, 56); drawEmberCounter(); finish("ember_counter")
begin(340, 480); drawStele(); finish("stele_result")

print("Generated \(generatedNames.count) images in \(String(format: "%.1f", Date().timeIntervalSince(t0)))s")
