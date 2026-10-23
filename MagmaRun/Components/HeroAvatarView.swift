import SwiftUI

/// The painted hero portrait with a breathing glow, shared by every menu.
struct HeroAvatarView: View {
    let skin: HeroSkin
    var size: CGFloat = 96
    var isAnimated = true

    @State private var bob = false

    var body: some View {
        ZStack {
            Circle()
                .fill(skin.glow.color.opacity(0.3))
                .frame(width: size * 0.8, height: size * 0.8)
                .blur(radius: size * 0.12)
                .scaleEffect(bob ? 1.08 : 0.94)

            Image(Art.heroPortrait(skin))
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .offset(y: bob ? -size * 0.015 : size * 0.015)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard isAnimated else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// The small painted ember used next to prices and balances.
struct EmberGlyph: View {
    var size: CGFloat = 14
    /// Sets the glyph on a dark coal disc so it reads on the bright molten buttons.
    var onMolten = false

    var body: some View {
        Image(Art.emberIcon)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(onMolten ? size * 0.18 : 0)
            .background {
                if onMolten {
                    Circle().fill(Chrome.moltenInk.opacity(0.85))
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(HeroSkin.allCases) { skin in
            HeroAvatarView(skin: skin, size: 80)
        }
    }
    .padding()
    .background(Theme.Colors.background)
}
