import SwiftUI

/// Central design tokens for the volcanic visual language used across the app.
enum Theme {
    enum Colors {
        static let background = Color(red: 0.055, green: 0.035, blue: 0.07)
        static let surface = Color(red: 0.12, green: 0.075, blue: 0.11)
        static let surfaceElevated = Color(red: 0.17, green: 0.105, blue: 0.15)
        static let stroke = Color.white.opacity(0.08)
        static let lava = Color(red: 1.0, green: 0.36, blue: 0.1)
        static let ember = Color(red: 1.0, green: 0.70, blue: 0.22)
        static let magma = Color(red: 0.86, green: 0.16, blue: 0.22)
        static let ash = Color(red: 0.64, green: 0.60, blue: 0.66)
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.66)
        static let textTertiary = Color.white.opacity(0.42)
        static let success = Color(red: 0.45, green: 0.86, blue: 0.55)
        static let danger = Color(red: 1.0, green: 0.33, blue: 0.36)
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 22
        static let smallCornerRadius: CGFloat = 14
        static let screenPadding: CGFloat = 20
        /// Maximum width of content columns so layouts stay readable on iPad.
        static let maxContentWidth: CGFloat = 720
    }

    static var lavaGradient: LinearGradient {
        LinearGradient(
            colors: [Colors.ember, Colors.lava, Colors.magma],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var emberGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.86, blue: 0.45), Colors.ember],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.06, blue: 0.1),
                Colors.background,
                Color(red: 0.03, green: 0.02, blue: 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Typography helpers

extension Font {
    /// Condensed, chiselled display face used for headlines, scores and big numbers.
    /// Scales with Dynamic Type relative to the title style. `weight` is kept for call sites
    /// but the face only ships one weight.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .custom("Futura-CondensedExtraBold", size: size, relativeTo: size >= 28 ? .largeTitle : .title3)
    }
}
