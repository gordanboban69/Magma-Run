import SwiftUI

/// Displays an ember amount with the flame glyph. Animates when the amount changes.
struct EmberBadge: View {
    let amount: Int
    var isCompact = false

    var body: some View {
        HStack(spacing: isCompact ? 4 : 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: isCompact ? 12 : 14, weight: .bold))
                .foregroundStyle(Theme.emberGradient)
            Text(Formatters.integer(amount))
                .font(.display(isCompact ? 14 : 16, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText(value: Double(amount)))
                .animation(.spring(duration: 0.4), value: amount)
        }
        .padding(.vertical, isCompact ? 6 : 8)
        .padding(.horizontal, isCompact ? 10 : 14)
        .background {
            Capsule()
                .fill(Theme.Colors.ember.opacity(0.14))
                .overlay(Capsule().strokeBorder(Theme.Colors.ember.opacity(0.35), lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) embers")
    }
}

/// A small labelled pill, used for hero stats and effects.
struct StatChip: View {
    let systemImage: String
    let text: String
    var tint: Color = Theme.Colors.ember

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(Capsule().fill(.white.opacity(0.07)))
    }
}
