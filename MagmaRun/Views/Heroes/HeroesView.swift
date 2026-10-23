import SwiftUI

/// Hero hall: a large showcase of one runner on a pedestal, with a roster of portraits below.
struct HeroesView: View {
    @State private var viewModel: HeroesViewModel
    /// The hero shown in the showcase. Starts on the equipped one.
    @State private var previewed: HeroSkin?
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(viewModel: HeroesViewModel) {
        self.viewModel = viewModel
    }

    private var isRegular: Bool { sizeClass == .regular }

    private var selected: HeroSkin {
        previewed ?? HeroSkin.allCases.first { viewModel.status(of: $0) == .equipped } ?? .starter
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("Every hero plays the same. Pick the one that feels like you.")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    EmberBadge(amount: viewModel.embers)
                }

                HeroShowcase(
                    skin: selected,
                    status: viewModel.status(of: selected),
                    canAfford: viewModel.canUnlock(selected),
                    shakeTrigger: viewModel.shakeCounts[selected] ?? 0,
                    heroSize: isRegular ? 280 : 210,
                    onActivate: { viewModel.activate(selected) }
                )
                .id(selected)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))

                FlameDivider()

                roster
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(VolcanoBackdrop(emberCount: 16))
        .stoneNavigation("Hall of Runners")
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Heroes.screen)
    }

    private var roster: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: isRegular ? 6 : 3)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(HeroSkin.allCases) { skin in
                RosterPortrait(
                    skin: skin,
                    status: viewModel.status(of: skin),
                    isSelected: skin == selected
                ) {
                    withAnimation(.spring(duration: 0.35)) {
                        previewed = skin
                    }
                }
            }
        }
    }
}

/// The selected hero standing on the pedestal, with lore and the unlock / equip slab.
private struct HeroShowcase: View {
    let skin: HeroSkin
    let status: HeroesViewModel.Status
    let canAfford: Bool
    let shakeTrigger: Int
    let heroSize: CGFloat
    let onActivate: () -> Void

    private var isLocked: Bool {
        if case .locked = status { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                Image(Chrome.pedestal)
                    .resizable()
                    .scaledToFit()
                    .frame(width: heroSize * 1.1)
                    .offset(y: heroSize * 0.12)
                HeroAvatarView(skin: skin, size: heroSize)
                    .saturation(isLocked ? 0.1 : 1)
                    .brightness(isLocked ? -0.15 : 0)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Theme.Colors.ash)
                        .frame(width: 48, height: 48)
                        .background(Image(Chrome.roundButton).resizable())
                        .offset(x: heroSize * 0.38, y: -heroSize * 0.75)
                        .accessibilityHidden(true)
                }
            }
            .padding(.bottom, heroSize * 0.1)

            StonePlaque {
                Text(skin.title)
                    .font(.display(24))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.ember)
            }

            Text(skin.lore)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            actionButton
                .frame(maxWidth: 300)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .cardBackground(isHighlighted: status == .equipped)
        .shake(trigger: shakeTrigger)
        .animation(.spring(duration: 0.35), value: status)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Heroes.heroCard(skin.id))
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .equipped:
            Text("EQUIPPED")
                .font(.display(16))
                .tracking(1)
                .foregroundStyle(Theme.Colors.success)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(NineSlice(piece: Chrome.stonePressed, scale: 0.9))
                .accessibilityIdentifier(AccessibilityID.Heroes.heroAction(skin.id))
        case .unlocked:
            Button("Equip", action: onActivate)
                .buttonStyle(LavaButtonStyle(isProminent: false))
                .accessibilityIdentifier(AccessibilityID.Heroes.heroAction(skin.id))
        case .locked(let price):
            Button(action: onActivate) {
                HStack(spacing: 8) {
                    Text("Unlock")
                    EmberGlyph(size: 16, onMolten: true)
                    Text(Formatters.integer(price))
                }
            }
            .buttonStyle(LavaButtonStyle(isProminent: canAfford))
            .opacity(canAfford ? 1 : 0.75)
            .accessibilityLabel("Unlock \(skin.title) for \(price) embers")
            .accessibilityIdentifier(AccessibilityID.Heroes.heroAction(skin.id))
        }
    }
}

/// A roster thumbnail on a small tablet; the selected one glows with molten seams.
private struct RosterPortrait: View {
    let skin: HeroSkin
    let status: HeroesViewModel.Status
    let isSelected: Bool
    let onSelect: () -> Void

    private var isLocked: Bool {
        if case .locked = status { return true }
        return false
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(Art.heroPortrait(skin))
                    .resizable()
                    .scaledToFit()
                    .saturation(isLocked ? 0 : 1)
                    .opacity(isLocked ? 0.55 : 1)
                    .padding(6)
                HStack(spacing: 4) {
                    switch status {
                    case .equipped:
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Theme.Colors.success)
                        Text("Equipped")
                    case .unlocked:
                        Text("Owned")
                    case .locked(let price):
                        EmberGlyph(size: 15)
                        Text(Formatters.integer(price))
                    }
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(height: 14)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .cardBackground(cornerRadius: Theme.Metrics.smallCornerRadius, isHighlighted: isSelected)
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Theme.Colors.ash)
                        .frame(width: 26, height: 26)
                        .background(Image(Chrome.roundButton).resizable())
                        .padding(6)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(RosterPressStyle())
        .accessibilityLabel("\(skin.title)\(isLocked ? ", locked" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("heroes.thumb.\(skin.id)")
    }
}

private struct RosterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.06 : 0)
    }
}
