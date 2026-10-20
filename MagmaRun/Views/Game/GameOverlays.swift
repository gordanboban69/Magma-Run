import SwiftUI

/// Dimmed backdrop shared by every overlay.
private struct OverlayScrim<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            content
                .frame(maxWidth: 440)
                .padding(.horizontal, 24)
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
                    StatChip(systemImage: "heart.fill", text: "\(loadout.maxHearts) hearts", tint: Theme.Colors.danger)
                    StatChip(systemImage: "hare.fill", text: "Speed \(Int(loadout.moveSpeed))")
                    if let recharge = loadout.shieldRecharge {
                        StatChip(systemImage: "shield.lefthalf.filled", text: "\(Int(recharge))s", tint: Color(red: 0.6, green: 0.8, blue: 1.0))
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

                Button("Back to camp", action: onQuit)
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
            }
            .padding(26)
            .cardBackground()
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
                .foregroundStyle(Theme.emberGradient)
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
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.emberGradient)
                Text("Paused")
                    .font(.display(28))
                    .foregroundStyle(Theme.Colors.textPrimary)
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

                Button("Quit to camp", action: onQuit)
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
            }
            .padding(26)
            .cardBackground()
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
                        .foregroundStyle(outcome.isNewBest ? AnyShapeStyle(Theme.emberGradient) : AnyShapeStyle(Theme.Colors.textPrimary))
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
                    ResultTile(title: "Embers", value: "+\(Formatters.integer(outcome.summary.embersCollected))", systemImage: "flame.fill", tint: Theme.Colors.ember)
                    ResultTile(title: "Survived", value: Formatters.duration(outcome.summary.duration), systemImage: "timer", tint: Color(red: 0.6, green: 0.8, blue: 1.0))
                    ResultTile(title: "Dodged", value: Formatters.integer(outcome.summary.bouldersDodged), systemImage: "figure.run", tint: Theme.Colors.success)
                    ResultTile(title: "Balance", value: Formatters.integer(outcome.totalEmbers), systemImage: "bag.fill", tint: Color(red: 0.8, green: 0.6, blue: 1.0))
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
            .padding(24)
            .cardBackground(isHighlighted: outcome.isNewBest)
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
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.16)))
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
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.06)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}
