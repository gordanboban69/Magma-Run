import SwiftUI

/// Upgrade shop where embers are spent on permanent hero improvements.
struct ForgeView: View {
    @State private var viewModel: ForgeViewModel

    init(viewModel: ForgeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 16) {
                balanceCard
                ForEach(UpgradeKind.allCases) { kind in
                    UpgradeRow(
                        kind: kind,
                        level: viewModel.level(of: kind),
                        cost: viewModel.nextCost(of: kind),
                        canAfford: viewModel.canPurchase(kind),
                        shakeTrigger: viewModel.shakeCounts[kind] ?? 0,
                        pulseTrigger: viewModel.pulseCounts[kind] ?? 0,
                        onForge: { viewModel.purchase(kind) }
                    )
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(VolcanoBackdrop(emberCount: 16))
        .navigationTitle("Forge")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityIdentifier(AccessibilityID.Forge.screen)
    }

    private var balanceCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.emberGradient)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Theme.Colors.lava.opacity(0.16)))
            VStack(alignment: .leading, spacing: 3) {
                Text("Your embers")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
                Text(Formatters.integer(viewModel.embers))
                    .font(.display(26))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .contentTransition(.numericText(value: Double(viewModel.embers)))
                    .animation(.spring(duration: 0.4), value: viewModel.embers)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("Maxed")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .textCase(.uppercase)
                Text("\(viewModel.maxedCount)/\(UpgradeKind.allCases.count)")
                    .font(.display(20))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(18)
        .cardBackground()
    }
}

/// One upgrade with its level, effect preview and forge button.
private struct UpgradeRow: View {
    let kind: UpgradeKind
    let level: Int
    let cost: Int?
    let canAfford: Bool
    let shakeTrigger: Int
    let pulseTrigger: Int
    let onForge: () -> Void

    @State private var pulse = false

    private var isMaxed: Bool { cost == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.Colors.ember.opacity(0.14))
                    )
                    .scaleEffect(pulse ? 1.15 : 1)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(kind.title)
                            .font(.display(18))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        LevelPips(level: level, maxLevel: kind.maxLevel)
                    }
                    Text(kind.summary)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                effectColumn(title: "Now", value: kind.effectDescription(atLevel: level), tint: Theme.Colors.textSecondary)
                if !isMaxed {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    effectColumn(title: "Next", value: kind.effectDescription(atLevel: level + 1), tint: Theme.Colors.success)
                }
                Spacer()
                forgeButton
            }
        }
        .padding(18)
        .cardBackground(isHighlighted: isMaxed)
        .shake(trigger: shakeTrigger)
        .onChange(of: pulseTrigger) { _, _ in
            withAnimation(.spring(duration: 0.3, bounce: 0.6)) { pulse = true }
            withAnimation(.spring(duration: 0.4).delay(0.3)) { pulse = false }
        }
    }

    private func effectColumn(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private var forgeButton: some View {
        if let cost {
            Button(action: onForge) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(Formatters.integer(cost))
                }
            }
            .buttonStyle(CompactLavaButtonStyle(isEnabledLook: canAfford))
            .accessibilityLabel("Forge \(kind.title) for \(cost) embers")
            .accessibilityIdentifier(AccessibilityID.Forge.upgradeButton(kind.id))
        } else {
            Text("MAXED")
                .font(.display(13, weight: .black))
                .foregroundStyle(Theme.Colors.ember)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Capsule().strokeBorder(Theme.Colors.ember.opacity(0.6), lineWidth: 1.5))
                .accessibilityIdentifier(AccessibilityID.Forge.upgradeButton(kind.id))
        }
    }
}
