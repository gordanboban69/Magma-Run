import SwiftUI

/// A row of pips showing the current level out of the maximum.
struct LevelPips: View {
    let level: Int
    let maxLevel: Int
    var tint: Color = Theme.Colors.ember

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Capsule()
                    .fill(index < level ? AnyShapeStyle(Theme.emberGradient) : AnyShapeStyle(Color.white.opacity(0.12)))
                    .frame(width: index < level ? 18 : 14, height: 6)
                    .shadow(color: index < level ? tint.opacity(0.6) : .clear, radius: 4)
                    .animation(.spring(duration: 0.35, bounce: 0.4).delay(Double(index) * 0.03), value: level)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level) of \(maxLevel)")
    }
}

/// Circular progress ring used for achievements and the shield gauge.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 4
    var tint: Color = Theme.Colors.ember

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: progress)
        }
    }
}
