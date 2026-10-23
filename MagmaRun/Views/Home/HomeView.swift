import SwiftUI

/// The camp at the foot of the volcano: the chosen hero on a basalt pedestal,
/// the molten PLAY slab and a row of carved stone tablets leading to every other screen.
struct HomeView: View {
    let onPlay: () -> Void

    @Environment(ProfileStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var playPulse = false

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        GeometryReader { proxy in
            // Wide, short windows (iPad landscape) put the hero beside the menu so nothing scrolls away.
            let isWide = proxy.size.width > proxy.size.height * 1.15 && proxy.size.width > 700
            ScrollView {
                if isWide {
                    VStack(spacing: 14) {
                        topBar
                        HStack(alignment: .center, spacing: 36) {
                            heroStage(heroSize: min(proxy.size.height * 0.36, 260))
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 18) {
                                header
                                playButton
                                FlameDivider()
                                tabletRow
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Metrics.screenPadding + 12)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                } else {
                    VStack(spacing: isRegular ? 26 : 18) {
                        topBar
                        header
                        heroStage(heroSize: isRegular ? 230 : 180)
                        playButton
                        FlameDivider()
                        tabletRow
                    }
                    .frame(maxWidth: Theme.Metrics.maxContentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Metrics.screenPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(VolcanoBackdrop(emberCount: 20, art: Art.homeBackdrop))
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Home.screen)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                playPulse = true
            }
        }
    }

    // MARK: - Sections

    /// Balance and settings, drawn in the game's own stone chrome rather than system bars.
    private var topBar: some View {
        HStack {
            EmberBadge(amount: store.profile.embers)
                .accessibilityIdentifier(AccessibilityID.Home.emberBalance)
            Spacer()
            NavigationLink(value: Route.settings) {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("Settings")
            .accessibilityIdentifier(AccessibilityID.Home.settingsButton)
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Image(Art.logo)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: isRegular ? 420 : 300)
                .shadow(color: Theme.Colors.lava.opacity(0.45), radius: 14)
                .accessibilityLabel("Magma Run")
                .accessibilityAddTraits(.isHeader)
            Text("Outrun the eruption.")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    /// The hero stands on a glowing pedestal; tapping the stage opens the hero roster.
    private func heroStage(heroSize: CGFloat) -> some View {
        let loadout = store.loadout
        return NavigationLink(value: Route.heroes) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottom) {
                    Image(Chrome.pedestal)
                        .resizable()
                        .scaledToFit()
                        .frame(width: heroSize * 1.15)
                        .offset(y: heroSize * 0.12)
                    HeroAvatarView(skin: loadout.skin, size: heroSize)
                }
                .padding(.bottom, heroSize * 0.12)

                StonePlaque {
                    Text(loadout.skin.title)
                        .font(.display(22))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.ember)
                }
                .frame(maxWidth: 320)
                Text(loadout.skin.lore)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    StatChip(systemImage: "heart.fill", text: "\(loadout.maxHearts) hearts", tint: Theme.Colors.danger, art: Art.HUD.heartFull)
                    StatChip(systemImage: "hare.fill", text: "Speed \(Int(loadout.moveSpeed))", art: Art.upgrade(.agility))
                    if loadout.shieldRecharge != nil {
                        StatChip(systemImage: "shield.lefthalf.filled", text: "Shield \(loadout.shield)", tint: Color(red: 0.6, green: 0.8, blue: 1.0), art: Art.HUD.shield)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Current hero: \(loadout.skin.title). Open heroes.")
    }

    private var playButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Play")
                    .tracking(3)
            }
            .font(.display(26))
        }
        .buttonStyle(LavaButtonStyle())
        .frame(maxWidth: 420)
        .shadow(color: Theme.Colors.lava.opacity(playPulse ? 0.6 : 0.2), radius: playPulse ? 24 : 10)
        .accessibilityIdentifier(AccessibilityID.Home.playButton)
    }

    private var tabletRow: some View {
        HStack(alignment: .top, spacing: isRegular ? 18 : 8) {
            MenuTablet(title: "Forge", subtitle: "\(maxedUpgrades)/\(UpgradeKind.allCases.count) maxed", art: Art.Menu.forge, route: .forge)
                .accessibilityIdentifier(AccessibilityID.Home.forgeButton)
            MenuTablet(title: "Heroes", subtitle: "\(unlockedHeroes)/\(HeroSkin.allCases.count) owned", art: Art.Menu.heroes, route: .heroes)
                .accessibilityIdentifier(AccessibilityID.Home.heroesButton)
            MenuTablet(title: "Records", subtitle: "Best \(Formatters.integer(store.profile.bestScore))", art: Art.Menu.records, route: .records)
                .accessibilityIdentifier(AccessibilityID.Home.recordsButton)
            MenuTablet(title: "Guide", subtitle: "How to play", art: Art.Menu.howTo, route: .howToPlay)
                .accessibilityIdentifier(AccessibilityID.Home.howToPlayButton)
        }
        .frame(maxWidth: isRegular ? 680 : .infinity)
    }

    private var maxedUpgrades: Int {
        UpgradeKind.allCases.filter { store.level(of: $0) >= $0.maxLevel }.count
    }

    private var unlockedHeroes: Int {
        HeroSkin.allCases.filter { store.profile.isUnlocked($0) }.count
    }
}

/// A standing stone tablet with a painted icon; the label is carved into its base.
private struct MenuTablet: View {
    let title: String
    let subtitle: String
    let art: String
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            VStack(spacing: 6) {
                ZStack {
                    Image(Chrome.menuTablet)
                        .resizable()
                        .scaledToFit()
                    GeometryReader { proxy in
                        VStack(spacing: 0) {
                            Image(art)
                                .resizable()
                                .scaledToFit()
                                .frame(height: proxy.size.height * 0.46)
                                .padding(.top, proxy.size.height * 0.12)
                            Spacer(minLength: 0)
                            Text(title)
                                .font(.display(min(18, proxy.size.width * 0.2)))
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.Colors.ember)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .padding(.horizontal, proxy.size.width * 0.12)
                                // Sits in the darker carved band near the base.
                                .frame(height: proxy.size.height * 0.18)
                                .padding(.bottom, proxy.size.height * 0.16)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .aspectRatio(150.0 / 170.0, contentMode: .fit)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TabletPressStyle())
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

/// Tablets dip and darken slightly when pressed, like stone pushed into the ground.
private struct TabletPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 3 : 0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}
