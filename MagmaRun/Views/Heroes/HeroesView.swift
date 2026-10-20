import SwiftUI

/// Hero gallery: preview, unlock and equip skins.
struct HeroesView: View {
    @State private var viewModel: HeroesViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(viewModel: HeroesViewModel) {
        self.viewModel = viewModel
    }

    private var columns: [GridItem] {
        let count = sizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    SectionHeader(title: "Choose your runner", subtitle: "Every hero plays the same. Pick the one that feels like you.")
                    EmberBadge(amount: viewModel.embers)
                }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(HeroSkin.allCases) { skin in
                        HeroCard(
                            skin: skin,
                            status: viewModel.status(of: skin),
                            canAfford: viewModel.canUnlock(skin),
                            shakeTrigger: viewModel.shakeCounts[skin] ?? 0,
                            onActivate: { viewModel.activate(skin) }
                        )
                    }
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(VolcanoBackdrop(emberCount: 16))
        .navigationTitle("Heroes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Heroes.screen)
    }
}

private struct HeroCard: View {
    let skin: HeroSkin
    let status: HeroesViewModel.Status
    let canAfford: Bool
    let shakeTrigger: Int
    let onActivate: () -> Void

    private var isEquipped: Bool { status == .equipped }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                HeroAvatarView(skin: skin, size: 110)
                    .frame(maxWidth: .infinity)
                    .saturation(isLocked ? 0.15 : 1)
                    .opacity(isLocked ? 0.7 : 1)
                if isEquipped {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Colors.success)
                        .transition(.scale.combined(with: .opacity))
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            Text(skin.title)
                .font(.display(16))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(skin.lore)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            actionButton
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .cardBackground(isHighlighted: isEquipped)
        .shake(trigger: shakeTrigger)
        .animation(.spring(duration: 0.35), value: status)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Heroes.heroCard(skin.id))
    }

    private var isLocked: Bool {
        if case .locked = status { return true }
        return false
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .equipped:
            Text("EQUIPPED")
                .font(.display(12, weight: .black))
                .foregroundStyle(Theme.Colors.success)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Capsule().strokeBorder(Theme.Colors.success.opacity(0.6), lineWidth: 1.5))
                .accessibilityIdentifier(AccessibilityID.Heroes.heroAction(skin.id))
        case .unlocked:
            Button("Select", action: onActivate)
                .buttonStyle(CompactLavaButtonStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(AccessibilityID.Heroes.heroAction(skin.id))
        case .locked(let price):
            Button(action: onActivate) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(Formatters.integer(price))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CompactLavaButtonStyle(isEnabledLook: canAfford))
            .accessibilityLabel("Unlock \(skin.title) for \(price) embers")
            .accessibilityIdentifier(AccessibilityID.Heroes.heroAction(skin.id))
        }
    }
}
