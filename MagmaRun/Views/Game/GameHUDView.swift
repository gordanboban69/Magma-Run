import SwiftUI

/// Hearts, shield, rage, score, embers, combo and mood banners shown over the running scene.
struct GameHUDView: View {
    let hud: GameHUDState
    let isVisible: Bool
    let onPause: () -> Void

    private let shieldTint = Color(red: 0.6, green: 0.8, blue: 1.0)
    private let rageTint = Color(red: 1.0, green: 0.45, blue: 0.2)

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    hearts
                    if hud.hasShield {
                        gauge(progress: hud.shieldCharge, systemImage: "shield.fill", tint: shieldTint,
                              text: hud.shieldCharge >= 1 ? "Shield ready" : "Recharging")
                    }
                    gauge(progress: hud.rage, systemImage: "dot.radiowaves.left.and.right", tint: rageTint,
                          text: hud.rage >= 1 ? "Shockwave!" : "Rage \(Int(hud.rage * 100))%")
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
                    comboPips
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            banner
            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: isVisible)
        .allowsHitTesting(isVisible)
    }

    // MARK: - Pieces

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

    private func gauge(progress: Double, systemImage: String, tint: Color, text: String) -> some View {
        let isFull = progress >= 1
        return HStack(spacing: 6) {
            ZStack {
                ProgressRing(progress: progress, lineWidth: 3, tint: tint)
                    .frame(width: 22, height: 22)
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isFull ? tint : .white.opacity(0.4))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isFull ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Capsule().fill(.black.opacity(0.35)))
        .shadow(color: isFull ? tint.opacity(0.6) : .clear, radius: 8)
        .animation(.easeOut(duration: 0.3), value: isFull)
        .accessibilityElement(children: .combine)
    }

    /// Ember streak toward the next overdrive.
    private var comboPips: some View {
        HStack(spacing: 3) {
            ForEach(0..<RunSession.overdriveComboLength, id: \.self) { index in
                Circle()
                    .fill(index < hud.combo || hud.isOverdrive ? AnyShapeStyle(Theme.emberGradient) : AnyShapeStyle(Color.white.opacity(0.18)))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 9)
        .background(Capsule().fill(.black.opacity(0.35)))
        .animation(.spring(duration: 0.3), value: hud.combo)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ember streak \(hud.combo) of \(RunSession.overdriveComboLength)")
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
                .fill(.black.opacity(0.62))
        )
        // Keep the rolling digits inside the pill.
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// One line of context: overdrive, incoming mood, active mood or a lava warning.
    @ViewBuilder
    private var banner: some View {
        if hud.isOverdrive {
            bannerLabel("OVERDRIVE \(Int(hud.overdriveRemaining.rounded(.up)))s", systemImage: "bolt.fill", tint: Theme.Colors.ember)
        } else if let upcoming = hud.upcomingMood {
            bannerLabel(upcoming.warningText, systemImage: upcoming.systemImage, tint: Theme.Colors.danger)
        } else if hud.lavaWarning {
            bannerLabel("Lava rising! Move!", systemImage: "exclamationmark.triangle.fill", tint: Theme.Colors.lava)
        } else if hud.mood != .steady {
            bannerLabel("\(hud.mood.title) \(Int(hud.moodRemaining.rounded(.up)))s", systemImage: hud.mood.systemImage, tint: Theme.Colors.textPrimary)
        }
    }

    private func bannerLabel(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.display(14, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(Capsule().fill(.black.opacity(0.45)))
            .shadow(color: tint.opacity(0.5), radius: 10)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .id(text)
            .animation(.spring(duration: 0.3), value: text)
    }
}
