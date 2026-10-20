import SwiftUI

/// Hearts, shield, score and embers shown over the running scene.
struct GameHUDView: View {
    let hud: GameHUDState
    let isVisible: Bool
    let onPause: () -> Void

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    hearts
                    if hud.hasShield {
                        shieldGauge
                    }
                }
                Spacer()
                scoreBlock
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Pause")
                    .accessibilityIdentifier(AccessibilityID.Game.pauseButton)
                    EmberBadge(amount: hud.embers, isCompact: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: isVisible)
        .allowsHitTesting(isVisible)
    }

    private var hearts: some View {
        HStack(spacing: 4) {
            ForEach(0..<hud.maxHearts, id: \.self) { index in
                Image(systemName: index < hud.hearts ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(index < hud.hearts ? Theme.Colors.danger : .white.opacity(0.35))
                    .shadow(color: index < hud.hearts ? Theme.Colors.danger.opacity(0.7) : .clear, radius: 6)
                    .scaleEffect(index < hud.hearts ? 1 : 0.85)
                    .animation(.spring(duration: 0.35, bounce: 0.5), value: hud.hearts)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Capsule().fill(.black.opacity(0.35)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hud.hearts) of \(hud.maxHearts) hearts")
    }

    private var shieldGauge: some View {
        let isReady = hud.shieldCharge >= 1
        let shieldTint = Color(red: 0.6, green: 0.8, blue: 1.0)
        return HStack(spacing: 6) {
            ZStack {
                ProgressRing(progress: hud.shieldCharge, lineWidth: 3, tint: shieldTint)
                    .frame(width: 22, height: 22)
                Image(systemName: "shield.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isReady ? shieldTint : .white.opacity(0.4))
            }
            Text(isReady ? "Shield ready" : "Recharging")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isReady ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Capsule().fill(.black.opacity(0.35)))
        .shadow(color: isReady ? shieldTint.opacity(0.5) : .clear, radius: 8)
        .animation(.easeOut(duration: 0.3), value: isReady)
    }

    private var scoreBlock: some View {
        VStack(spacing: 0) {
            Text(Formatters.integer(hud.score))
                .font(.display(36, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                .contentTransition(.numericText(value: Double(hud.score)))
                .animation(.linear(duration: 0.1), value: hud.score)
                .accessibilityIdentifier(AccessibilityID.Game.scoreLabel)
            Text(Formatters.duration(hud.elapsed))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.4))
        )
        .accessibilityElement(children: .combine)
    }
}
