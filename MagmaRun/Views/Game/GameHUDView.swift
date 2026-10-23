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
            // Side columns share the width equally so the score stays centred over the crater.
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    hearts
                    if hud.hasShield {
                        gauge(progress: hud.shieldCharge, art: Art.HUD.shield, tint: shieldTint,
                              text: hud.shieldCharge >= 1 ? "Shield ready" : "Recharging")
                    }
                    gauge(progress: hud.rage, art: Art.HUD.rage, tint: rageTint,
                          text: hud.rage >= 1 ? "Shockwave!" : "Rage \(Int(hud.rage * 100))%")
                    shardPips
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                scoreBlock
                    .fixedSize()
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
                .frame(maxWidth: .infinity, alignment: .trailing)
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
        // Rows of three keep the chip narrow even with every Vitality level forged.
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(stride(from: 0, to: hud.maxHearts, by: 3)), id: \.self) { rowStart in
                HStack(spacing: 4) {
                    ForEach(rowStart..<min(rowStart + 3, hud.maxHearts), id: \.self) { index in
                        Image(index < hud.hearts ? Art.HUD.heartFull : Art.HUD.heartEmpty)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .opacity(index < hud.hearts ? 1 : 0.6)
                            .scaleEffect(index < hud.hearts ? 1 : 0.85)
                            .animation(.spring(duration: 0.35, bounce: 0.5), value: hud.hearts)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(NineSlice(piece: Chrome.chip, scale: 0.55))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hud.hearts) of \(hud.maxHearts) hearts")
    }

    private func gauge(progress: Double, art: String, tint: Color, text: String) -> some View {
        let isFull = progress >= 1
        return HStack(spacing: 6) {
            ZStack {
                ProgressRing(progress: progress, lineWidth: 3, tint: tint)
                    .frame(width: 24, height: 24)
                Image(art)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
                    .saturation(isFull ? 1 : 0.2)
                    .opacity(isFull ? 1 : 0.7)
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isFull ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(NineSlice(piece: Chrome.chip, scale: 0.55))
        .shadow(color: isFull ? tint.opacity(0.6) : .clear, radius: 8)
        .animation(.easeOut(duration: 0.3), value: isFull)
        .accessibilityElement(children: .combine)
    }

    /// Heart shards held toward the next restored heart.
    private var shardPips: some View {
        HStack(spacing: 2) {
            ForEach(0..<RunSession.shardsPerHeart, id: \.self) { index in
                Image(Art.HUD.shard)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .saturation(index < hud.heartShards ? 1 : 0)
                    .brightness(index < hud.heartShards ? 0 : 0.25)
                    .opacity(index < hud.heartShards ? 1 : 0.6)
            }
            Text("Shards")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.leading, 3)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(NineSlice(piece: Chrome.chip, scale: 0.55))
        .animation(.spring(duration: 0.3), value: hud.heartShards)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart shards \(hud.heartShards) of \(RunSession.shardsPerHeart)")
    }

    /// Ember streak toward the next overdrive.
    private var comboPips: some View {
        HStack(spacing: 3) {
            ForEach(0..<RunSession.overdriveComboLength, id: \.self) { index in
                Image(index < hud.combo || hud.isOverdrive ? Chrome.socketFull : Chrome.socketEmpty)
                    .resizable()
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 9)
        .background(NineSlice(piece: Chrome.chip, scale: 0.55))
        .animation(.spring(duration: 0.3), value: hud.combo)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ember streak \(hud.combo) of \(RunSession.overdriveComboLength)")
    }

    private var scoreBlock: some View {
        VStack(spacing: 0) {
            Text(Formatters.integer(hud.score))
                .font(.display(38, weight: .black))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(Theme.Colors.textPrimary)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                .accessibilityIdentifier(AccessibilityID.Game.scoreLabel)
            Text(Formatters.duration(hud.elapsed))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .padding(.horizontal, 6)
        .background(NineSlice(piece: Chrome.toast, scale: 0.6))
        .accessibilityElement(children: .combine)
    }

    /// One line of context: overdrive, incoming mood, active mood or a lava warning.
    @ViewBuilder
    private var banner: some View {
        if hud.isOverdrive {
            bannerLabel("OVERDRIVE \(Int(hud.overdriveRemaining.rounded(.up)))s", art: Art.HUD.overdrive, tint: Theme.Colors.ember)
        } else if let upcoming = hud.upcomingMood {
            bannerLabel(upcoming.warningText, art: Art.mood(upcoming), tint: Theme.Colors.danger)
        } else if hud.lavaWarning {
            bannerLabel("Lava rising! Move!", art: nil, tint: Theme.Colors.lava)
        } else if hud.isOnCrust {
            bannerLabel("Obsidian crust: score x2", art: Art.HUD.crust, tint: Theme.Colors.ember)
        } else if hud.hasCrust {
            // The crust is short-lived, so its hint outranks the ongoing mood banner.
            bannerLabel("Stand on the crust for x2", art: Art.HUD.crust, tint: Theme.Colors.textPrimary)
        } else if hud.mood != .steady {
            bannerLabel("\(hud.mood.title) \(Int(hud.moodRemaining.rounded(.up)))s", art: Art.mood(hud.mood), tint: Theme.Colors.textPrimary)
        }
    }

    /// `art: nil` shows the system warning glyph instead of painted art.
    private func bannerLabel(_ text: String, art: String?, tint: Color) -> some View {
        Label {
            Text(text)
        } icon: {
            if let art {
                Image(art)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
            }
        }
            .font(.display(14, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(NineSlice(piece: Chrome.toast, scale: 0.6))
            .shadow(color: tint.opacity(0.5), radius: 10)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .id(text)
            .animation(.spring(duration: 0.3), value: text)
    }
}
