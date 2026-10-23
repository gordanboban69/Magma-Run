import SwiftUI

/// A compact statistic tablet with a painted icon, a value and a caption.
struct StatTile: View {
    let title: String
    let value: String
    var art: String?
    var systemImage = "circle"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TileIcon(art: art, systemImage: systemImage, size: 38)
            Text(value)
                .font(.display(24))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardBackground(cornerRadius: Theme.Metrics.smallCornerRadius + 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// A painted icon, or an ember-gold glyph set into a stone medallion when no art exists.
struct TileIcon: View {
    let art: String?
    var systemImage = "circle"
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let art {
                Image(art)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.38, weight: .black))
                    .foregroundStyle(Theme.Colors.ember)
                    .frame(width: size, height: size)
                    .background(Image(Chrome.roundButton).resizable())
            }
        }
        .accessibilityHidden(true)
    }
}

/// Section heading used across screens.
struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.display(22))
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.ember)
                .shadow(color: Theme.Colors.lava.opacity(0.4), radius: 6)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
