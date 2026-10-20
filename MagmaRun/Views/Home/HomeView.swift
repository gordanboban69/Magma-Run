import SwiftUI

/// The camp screen: hero overview, play button and navigation to every other screen.
struct HomeView: View {
    let onPlay: () -> Void

    @Environment(ProfileStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var playPulse = false

    private var menuColumns: [GridItem] {
        let count = sizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                heroCard
                playButton
                LazyVGrid(columns: menuColumns, spacing: 14) {
                    MenuCard(
                        title: "Forge",
                        subtitle: "\(maxedUpgrades)/\(UpgradeKind.allCases.count) maxed",
                        systemImage: "hammer.fill",
                        tint: Theme.Colors.lava,
                        route: .forge
                    )
                    .accessibilityIdentifier(AccessibilityID.Home.forgeButton)
                    MenuCard(
                        title: "Heroes",
                        subtitle: "\(unlockedHeroes)/\(HeroSkin.allCases.count) unlocked",
                        systemImage: "person.2.fill",
                        tint: Color(red: 0.7, green: 0.5, blue: 1.0),
                        route: .heroes
                    )
                    .accessibilityIdentifier(AccessibilityID.Home.heroesButton)
                    MenuCard(
                        title: "Records",
                        subtitle: "Best \(Formatters.integer(store.profile.bestScore))",
                        systemImage: "trophy.fill",
                        tint: Theme.Colors.ember,
                        route: .records
                    )
                    .accessibilityIdentifier(AccessibilityID.Home.recordsButton)
                    MenuCard(
                        title: "How to play",
                        subtitle: "Controls & tips",
                        systemImage: "questionmark.circle.fill",
                        tint: Color(red: 0.45, green: 0.85, blue: 0.95),
                        route: .howToPlay
                    )
                    .accessibilityIdentifier(AccessibilityID.Home.howToPlayButton)
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(VolcanoBackdrop())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape.fill")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Settings")
                .accessibilityIdentifier(AccessibilityID.Home.settingsButton)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Home.screen)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                playPulse = true
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MAGMA RUN")
                    .font(.display(34, weight: .black))
                    .foregroundStyle(Theme.emberGradient)
                    .shadow(color: Theme.Colors.lava.opacity(0.5), radius: 12)
                Text("Outrun the eruption.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            EmberBadge(amount: store.profile.embers)
                .accessibilityIdentifier(AccessibilityID.Home.emberBalance)
        }
        .padding(.top, 4)
    }

    private var heroCard: some View {
        let loadout = store.loadout
        return NavigationLink(value: Route.heroes) {
            HStack(spacing: 18) {
                HeroAvatarView(skin: loadout.skin, size: 104)
                VStack(alignment: .leading, spacing: 8) {
                    Text(loadout.skin.title)
                        .font(.display(22))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(loadout.skin.lore)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        StatChip(systemImage: "heart.fill", text: "\(loadout.maxHearts)", tint: Theme.Colors.danger)
                        StatChip(systemImage: "hare.fill", text: "Lv \(loadout.agility)")
                        if loadout.shieldRecharge != nil {
                            StatChip(systemImage: "shield.lefthalf.filled", text: "Lv \(loadout.shield)", tint: Color(red: 0.6, green: 0.8, blue: 1.0))
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(18)
            .cardBackground()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Current hero: \(loadout.skin.title). Open heroes.")
    }

    private var playButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("PLAY")
                    .tracking(2)
            }
            .font(.display(22, weight: .black))
        }
        .buttonStyle(LavaButtonStyle())
        .shadow(color: Theme.Colors.lava.opacity(playPulse ? 0.7 : 0.25), radius: playPulse ? 26 : 12)
        .accessibilityIdentifier(AccessibilityID.Home.playButton)
    }

    private var maxedUpgrades: Int {
        UpgradeKind.allCases.filter { store.level(of: $0) >= $0.maxLevel }.count
    }

    private var unlockedHeroes: Int {
        HeroSkin.allCases.filter { store.profile.isUnlocked($0) }.count
    }
}

/// A navigation tile on the home grid.
private struct MenuCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(tint.opacity(0.16)))
                Spacer(minLength: 0)
                Text(title)
                    .font(.display(17))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .cardBackground(cornerRadius: Theme.Metrics.smallCornerRadius + 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
