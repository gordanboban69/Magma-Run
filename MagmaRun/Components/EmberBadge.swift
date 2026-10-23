import SwiftUI

/// Displays an ember amount with the flame glyph. Animates when the amount changes.
struct EmberBadge: View {
    let amount: Int
    var isCompact = false

    var body: some View {
        // The counter art carries a brazier on its left end, so the number sits to its right.
        Text(Formatters.integer(amount))
            .font(.display(isCompact ? 15 : 18))
            .monospacedDigit()
            .foregroundStyle(Theme.Colors.ember)
            .contentTransition(.numericText(value: Double(amount)))
            .animation(.spring(duration: 0.4), value: amount)
            .padding(.leading, isCompact ? 34 : 44)
            .padding(.trailing, isCompact ? 14 : 18)
            .frame(minWidth: isCompact ? 86 : 112, minHeight: isCompact ? 34 : 44, alignment: .leading)
            .background { NineSlice(piece: Chrome.emberCounter, scale: isCompact ? 0.6 : 0.78) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) embers")
    }
}

/// A small labelled pill, used for hero stats and effects.
struct StatChip: View {
    let systemImage: String
    let text: String
    var tint: Color = Theme.Colors.ember
    /// Painted icon used instead of the glyph when available.
    var art: String?

    var body: some View {
        HStack(spacing: 5) {
            if let art {
                Image(art)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 11)
        .background(NineSlice(piece: Chrome.chip, scale: 0.6))
    }
}
