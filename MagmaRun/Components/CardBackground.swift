import SwiftUI

/// Dark obsidian card surface with a soft inner highlight.
struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = Theme.Metrics.cornerRadius
    var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.06), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                isHighlighted ? Theme.Colors.lava.opacity(0.7) : Theme.Colors.stroke,
                                lineWidth: isHighlighted ? 1.5 : 1
                            )
                    }
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            }
    }
}

extension View {
    /// Applies the standard card surface.
    func cardBackground(cornerRadius: CGFloat = Theme.Metrics.cornerRadius, isHighlighted: Bool = false) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}

/// Horizontal shake used to signal a rejected action.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = travel * sin(animatableData * .pi * shakes * 2)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

extension View {
    /// Shakes the view each time `trigger` changes.
    func shake(trigger: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(trigger)))
            .animation(.linear(duration: 0.4), value: trigger)
    }
}
