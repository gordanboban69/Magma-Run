import SwiftUI

/// Animated menu background: a dark volcanic gradient with drifting embers.
/// Drawn with `Canvas` inside a `TimelineView` so it costs no view updates.
struct VolcanoBackdrop: View {
    var emberCount = 28
    /// Optional painted scene drawn under the embers (scaled to fill).
    var art: String?

    private struct Ember {
        let x: Double
        let speed: Double
        let size: Double
        let phase: Double
        let wobble: Double
    }

    private let embers: [Ember]

    init(emberCount: Int = 28, art: String? = nil) {
        self.emberCount = emberCount
        self.art = art
        var generator = SeededGenerator(seed: 42)
        embers = (0..<emberCount).map { _ in
            Ember(
                x: Double.random(in: 0...1, using: &generator),
                speed: Double.random(in: 0.035...0.09, using: &generator),
                size: Double.random(in: 2...5.5, using: &generator),
                phase: Double.random(in: 0...1, using: &generator),
                wobble: Double.random(in: 6...22, using: &generator)
            )
        }
    }

    var body: some View {
        ZStack {
            Theme.Colors.background

            // Tiled basalt grain instead of a flat gradient.
            Image(Art.panelTexture)
                .resizable(resizingMode: .tile)
                .opacity(0.9)

            if let art {
                // Measured so a fill-scaled bitmap never widens the layout.
                GeometryReader { proxy in
                    Image(art)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            }

            // Warm glow rising from the bottom, like a lava field below the horizon.
            RadialGradient(
                colors: [Theme.Colors.lava.opacity(art == nil ? 0.22 : 0.12), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 520
            )

            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { canvas, size in
                    for ember in embers {
                        let progress = (time * ember.speed + ember.phase).truncatingRemainder(dividingBy: 1)
                        let y = size.height * (1 - progress) + 20
                        let x = size.width * ember.x + sin(time * 0.8 + ember.phase * 10) * ember.wobble
                        let alpha = sin(progress * .pi) * 0.9
                        let rect = CGRect(x: x - ember.size / 2, y: y - ember.size / 2, width: ember.size, height: ember.size)
                        canvas.fill(
                            Circle().path(in: rect.insetBy(dx: -ember.size, dy: -ember.size)),
                            with: .color(Theme.Colors.lava.opacity(alpha * 0.25))
                        )
                        canvas.fill(Circle().path(in: rect), with: .color(Theme.Colors.ember.opacity(alpha)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    VolcanoBackdrop()
}
