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
        /// Painted illustration shown above the text for the core mechanics.
        var illustration: String?
        /// Painted icon beside the title; falls back to the glyph in a stone medallion.
        var iconArt: String?
    }

    private let steps: [Step] = [
        Step(id: 0, title: "Steer the runner", detail: "Drag anywhere to move, or switch to left / right buttons in Settings.", systemImage: "hand.draw.fill", tint: Color(red: 0.45, green: 0.85, blue: 0.95), illustration: Art.Tutorial.controls, iconArt: Art.Menu.howTo),
        Step(id: 1, title: "Dodge the boulders", detail: "Rocks erupt from the crater and rain from the sky. Each hit costs a heart.", systemImage: "circle.hexagongrid.fill", tint: Theme.Colors.ash, iconArt: Art.boulder(variant: 1, hot: true)),
        Step(id: 2, title: "Collect embers", detail: "Glowing embers are your currency. Grab them mid-run to spend later.", systemImage: "flame.fill", tint: Theme.Colors.ember, iconArt: Art.ember),
        Step(id: 3, title: "Forge upgrades", detail: "Spend embers on speed, hearts, a recharging shield, a magnet and fortune.", systemImage: "hammer.fill", tint: Theme.Colors.lava, iconArt: Art.Menu.forge),
        Step(id: 4, title: "Build rage with near misses", detail: "Let boulders graze past you. Five close calls fill the rage bar and unleash a shockwave that shatters every rock nearby.", systemImage: "dot.radiowaves.left.and.right", tint: Color(red: 1.0, green: 0.45, blue: 0.2), illustration: Art.Tutorial.rage, iconArt: Art.HUD.rage),
        Step(id: 5, title: "Escape the lava rivers", detail: "Cracks start glowing on the ground: that strip floods with lava moments later. Standing in it costs a heart.", systemImage: "exclamationmark.triangle.fill", tint: Theme.Colors.lava, illustration: Art.Tutorial.lava, iconArt: Art.mood(.fury)),
        Step(id: 6, title: "Stand on the obsidian crust", detail: "When a river drains it cools into glossy black crust for a few seconds. Standing on it doubles your score and every near miss builds twice the rage.", systemImage: "square.stack.3d.down.forward.fill", tint: Color(red: 0.8, green: 0.6, blue: 1.0), illustration: Art.Tutorial.crust, iconArt: Art.HUD.crust),
        Step(id: 7, title: "Chain embers for overdrive", detail: "Six embers in a row without taking damage turn you molten for five seconds: boulders shatter on contact and embers count double.", systemImage: "bolt.fill", tint: Theme.Colors.ember, illustration: Art.Tutorial.overdrive, iconArt: Art.HUD.overdrive),
        Step(id: 8, title: "Gather heart shards", detail: "Hot, glowing boulders smashed by a shockwave or overdrive drop a red shard. Three shards restore a heart, or pay out embers when your hearts are full.", systemImage: "suit.heart.fill", tint: Theme.Colors.danger, illustration: Art.Tutorial.shards, iconArt: Art.HUD.shard),
        Step(id: 9, title: "Read the volcano's mood", detail: "A banner warns before each phase. Fury hurls aimed rocks, Ash Rain drops them from the sky, Ember Shower is your harvest window.", systemImage: "mountain.2.fill", tint: Color(red: 0.75, green: 0.62, blue: 0.70), illustration: Art.Tutorial.moods, iconArt: Art.mood(.ashRain)),
        Step(id: 10, title: "Survive longer", detail: "The eruption grows fiercer every second. Score climbs faster the longer you last.", systemImage: "chart.line.uptrend.xyaxis", tint: Theme.Colors.success, iconArt: Art.mood(.fury))
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if isOnboarding {
                    VStack(spacing: 6) {
                        Text("Welcome to the mountain")
                            .font(.display(26))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Eleven things to know before your first run.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 20)
                }

                ForEach(steps) { step in
                    VStack(alignment: .leading, spacing: 12) {
                        if let illustration = step.illustration {
                            Image(illustration)
                                .resizable()
                                .aspectRatio(320 / 200, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .padding(7)
                                .background(NineSlice(piece: Chrome.panel, scale: 0.4))
                                .accessibilityHidden(true)
                        }
                    HStack(alignment: .top, spacing: 14) {
                        TileIcon(art: step.iconArt, systemImage: step.systemImage, size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.display(19))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(step.detail)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
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
        .stoneNavigation("How to play", showsBackButton: !isOnboarding)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.HowToPlay.screen)
    }
}
