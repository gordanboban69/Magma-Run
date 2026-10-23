import SwiftUI

/// A carved basalt tablet behind content; highlighted tablets glow with molten seams.
struct CardBackground: ViewModifier {
    /// Kept for call-site compatibility: smaller radii render the tablet's border thinner.
    var cornerRadius: CGFloat = Theme.Metrics.cornerRadius
    var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .background {
                NineSlice(piece: isHighlighted ? Chrome.panelLava : Chrome.panel, scale: cornerRadius >= Theme.Metrics.cornerRadius ? 0.62 : 0.5)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
            }
    }
}

extension View {
    /// Applies the standard carved tablet surface.
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
