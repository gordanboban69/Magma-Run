import SwiftUI

/// SwiftUI rendition of the in-game hero so menus and the scene share one look.
struct HeroAvatarView: View {
    let skin: HeroSkin
    var size: CGFloat = 96
    var isAnimated = true

    @State private var bob = false

    var body: some View {
        let scale = size / 96
        ZStack {
            // Ambient glow behind the hero.
            Circle()
                .fill(skin.glow.color.opacity(0.35))
                .frame(width: size * 0.95, height: size * 0.95)
                .blur(radius: 14 * scale)
                .scaleEffect(bob ? 1.08 : 0.94)

            VStack(spacing: -6 * scale) {
                // Head with visor.
                ZStack {
                    Circle()
                        .fill(skin.primary.color)
                        .overlay(Circle().strokeBorder(skin.secondary.color, lineWidth: 2.5 * scale))
                        .frame(width: 30 * scale, height: 30 * scale)
                    Capsule()
                        .fill(skin.glow.color)
                        .frame(width: 18 * scale, height: 7 * scale)
                        .shadow(color: skin.glow.color, radius: 3 * scale)
                        .offset(y: -1 * scale)
                }
                .offset(y: bob ? -2 * scale : 2 * scale)
                .zIndex(1)

                // Body with emblem.
                ZStack {
                    RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                        .fill(skin.primary.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15 * scale, style: .continuous)
                                .strokeBorder(skin.secondary.color, lineWidth: 2.5 * scale)
                        )
                        .frame(width: 34 * scale, height: 44 * scale)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 10 * scale, weight: .bold))
                        .foregroundStyle(skin.glow.color)
                        .shadow(color: skin.glow.color, radius: 2 * scale)
                        .offset(y: 2 * scale)
                }
            }

            // Flame trail under the feet.
            Ellipse()
                .fill(
                    LinearGradient(colors: [skin.glow.color.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 26 * scale, height: 22 * scale)
                .blur(radius: 3 * scale)
                .offset(y: 40 * scale)
                .scaleEffect(x: bob ? 1.15 : 0.9, y: bob ? 1.2 : 0.85, anchor: .top)
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

#Preview {
    HStack {
        ForEach(HeroSkin.allCases) { skin in
            HeroAvatarView(skin: skin, size: 80)
        }
    }
    .padding()
    .background(Theme.Colors.background)
}
