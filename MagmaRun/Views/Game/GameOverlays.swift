import SwiftUI

/// Dimmed backdrop shared by every overlay.
private struct OverlayScrim<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
            content
                .frame(maxWidth: 440)
                .padding(.horizontal, 24)
        }
    }
}

extension View {
    /// Places overlay content on the carved obsidian stele; the arch on top stays clear.
    func steleBackground(isGlowing: Bool = false) -> some View {
        padding(.horizontal, 30)
            .padding(.top, 92)
            .padding(.bottom, 56)
            .background {
                NineSlice(piece: Chrome.stele, scale: 0.75)
                    .shadow(color: isGlowing ? Theme.Colors.lava.opacity(0.6) : .black.opacity(0.6), radius: isGlowing ? 26 : 18)
            }
    }
}

/// Shown before the eruption starts.
struct ReadyOverlay: View {
    let hero: HeroSkin
    let loadout: HeroLoadout
    let bestScore: Int
    let controlScheme: ControlScheme
    let onStart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        OverlayScrim {
            VStack(spacing: 18) {
                HeroAvatarView(skin: hero, size: 120)
                VStack(spacing: 6) {
                    Text(hero.title)
                        .font(.display(26))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Best \(Formatters.integer(bestScore))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                HStack(spacing: 8) {
                    StatChip(systemImage: "heart.fill", text: "\(loadout.maxHearts) hearts", tint: Theme.Colors.danger, art: Art.HUD.heartFull)
                    StatChip(systemImage: "hare.fill", text: "Speed \(Int(loadout.moveSpeed))", art: Art.upgrade(.agility))
                    if let recharge = loadout.shieldRecharge {
                        StatChip(systemImage: "shield.lefthalf.filled", text: "\(Int(recharge))s", tint: Color(red: 0.6, green: 0.8, blue: 1.0), art: Art.HUD.shield)
                    }
                }
                Label(
                    controlScheme == .drag ? "Drag anywhere to move" : "Hold the left or right side to move",
                    systemImage: controlScheme.systemImage
                )
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)

                Button(action: onStart) {
                    Label("Start the eruption", systemImage: "flame.fill")
                }
                .buttonStyle(LavaButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.startButton)

                Button(action: onQuit) {
                    Label("Back to camp", systemImage: "house.fill")
                }
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
            }
            .steleBackground()
        }
    }
}

/// Big animated number before the run begins.
struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            Text("\(value)")
                .font(.display(120, weight: .black))
                .foregroundStyle(Theme.Colors.ember)
                .shadow(color: Chrome.moltenInk, radius: 0, x: 3, y: 4)
                .shadow(color: Theme.Colors.lava.opacity(0.8), radius: 30)
                .id(value)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
                .animation(.spring(duration: 0.4, bounce: 0.3), value: value)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Starting in \(value)")
    }
}

/// Pause menu.
struct PauseOverlay: View {
    let score: Int
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        OverlayScrim {
            VStack(spacing: 16) {
                Text("Paused")
                    .font(.display(30))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.ember)
                Text("Score so far: \(Formatters.integer(score))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Button(action: onResume) {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(LavaButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.resumeButton)

                Button(action: onRestart) {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GhostButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.restartButton)

                Button(action: onQuit) {
                    Label("Quit to camp", systemImage: "house.fill")
                }
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
            }
            .steleBackground()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Game.pausedOverlay)
        }
    }
}

/// Results card shown after the final hit.
struct GameOverView: View {
    let outcome: RunOutcome
    let onPlayAgain: () -> Void
    let onForge: () -> Void
    let onQuit: () -> Void

    @State private var revealed = false

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        OverlayScrim {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(outcome.isNewBest ? "NEW BEST!" : "The mountain wins")
                        .font(.display(outcome.isNewBest ? 30 : 26, weight: .black))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.ember)
                        .shadow(color: outcome.isNewBest ? Theme.Colors.lava.opacity(0.7) : .clear, radius: 16)
                    Text(Formatters.integer(outcome.summary.score))
                        .font(.display(56, weight: .black))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(outcome.isNewBest
                         ? "Previous best \(Formatters.integer(outcome.previousBest))"
                         : "Best \(Formatters.integer(outcome.previousBest))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ResultTile(title: "Embers", value: "+\(Formatters.integer(outcome.summary.embersCollected))", art: Art.emberIcon)
                    ResultTile(title: "Survived", value: Formatters.duration(outcome.summary.duration), systemImage: "timer")
                    ResultTile(title: "Dodged", value: Formatters.integer(outcome.summary.bouldersDodged), art: Art.boulder(variant: 0, hot: false))
                    ResultTile(title: "Balance", value: Formatters.integer(outcome.totalEmbers), art: Art.upgrade(.fortune))
                    ResultTile(title: "Heart shards", value: Formatters.integer(outcome.summary.heartShards), art: Art.HUD.shard)
                    ResultTile(title: "On crust", value: Formatters.duration(outcome.summary.crustTime), art: Art.HUD.crust)
                }

                Button(action: onPlayAgain) {
                    Label("Run again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(LavaButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.restartButton)

                HStack(spacing: 10) {
                    Button(action: onForge) {
                        Label("Forge", systemImage: "hammer.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button(action: onQuit) {
                        Label("Camp", systemImage: "house.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
                }
            }
            .steleBackground(isGlowing: outcome.isNewBest)
            .scaleEffect(revealed ? 1 : 0.9)
            .opacity(revealed ? 1 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Game.gameOverOverlay)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                revealed = true
            }
        }
    }
}

private struct ResultTile: View {
    let title: String
    let value: String
    var art: String?
    var systemImage = "circle"

    var body: some View {
        HStack(spacing: 10) {
            TileIcon(art: art, systemImage: systemImage, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.display(17))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(NineSlice(piece: Chrome.chip, scale: 0.7))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}
