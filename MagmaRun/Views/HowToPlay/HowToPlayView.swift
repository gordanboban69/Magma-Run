import SwiftUI

/// Tutorial shown before the first run and available any time from the camp.
struct HowToPlayView: View {
    let isOnboarding: Bool
    let onContinue: (() -> Void)?

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
        let systemImage: String
        let tint: Color
    }

    private let steps: [Step] = [
        Step(id: 0, title: "Steer the runner", detail: "Drag anywhere to move, or switch to left / right buttons in Settings.", systemImage: "hand.draw.fill", tint: Color(red: 0.45, green: 0.85, blue: 0.95)),
        Step(id: 1, title: "Dodge the boulders", detail: "Rocks erupt from the crater and rain from the sky. Each hit costs a heart.", systemImage: "circle.hexagongrid.fill", tint: Theme.Colors.ash),
        Step(id: 2, title: "Collect embers", detail: "Glowing embers are your currency. Grab them mid-run to spend later.", systemImage: "flame.fill", tint: Theme.Colors.ember),
        Step(id: 3, title: "Forge upgrades", detail: "Spend embers on speed, hearts, a recharging shield, a magnet and fortune.", systemImage: "hammer.fill", tint: Theme.Colors.lava),
        Step(id: 4, title: "Survive longer", detail: "The eruption grows fiercer every second. Score climbs faster the longer you last.", systemImage: "chart.line.uptrend.xyaxis", tint: Theme.Colors.success)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if isOnboarding {
                    VStack(spacing: 6) {
                        Text("Welcome to the mountain")
                            .font(.display(26))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Five things to know before your first run.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 20)
                }

                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: step.systemImage)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(step.tint)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(step.tint.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.display(16))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(step.detail)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .cardBackground(cornerRadius: Theme.Metrics.smallCornerRadius + 4)
                }

                if let onContinue {
                    Button(action: onContinue) {
                        Label("Let's run", systemImage: "flame.fill")
                    }
                    .buttonStyle(LavaButtonStyle())
                    .padding(.top, 6)
                    .accessibilityIdentifier("howToPlay.continue")
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(VolcanoBackdrop(emberCount: 12))
        .navigationTitle("How to play")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.HowToPlay.screen)
    }
}
