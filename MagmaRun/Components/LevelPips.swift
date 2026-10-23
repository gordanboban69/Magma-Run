import SwiftUI

/// A row of pips showing the current level out of the maximum.
struct LevelPips: View {
    let level: Int
    let maxLevel: Int
    var tint: Color = Theme.Colors.ember

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Image(index < level ? Chrome.socketFull : Chrome.socketEmpty)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .scaleEffect(index < level ? 1 : 0.9)
                    .animation(.spring(duration: 0.35, bounce: 0.5).delay(Double(index) * 0.04), value: level)
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
