import SwiftUI

/// Preferences, progress reset and app information.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var settings = viewModel.settings
        ScrollView {
            VStack(spacing: 16) {
                settingsGroup(title: "Gameplay") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Controls", systemImage: settings.controlScheme.systemImage)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        // Two carved slabs; the chosen scheme glows molten.
                        HStack(spacing: 10) {
                            ForEach(ControlScheme.allCases) { scheme in
                                let isSelected = settings.controlScheme == scheme
                                Button {
                                    settings.controlScheme = scheme
                                } label: {
                                    Label(scheme.shortTitle, systemImage: scheme.systemImage)
                                        .font(.display(16))
                                        .lineLimit(1)
                                        .textCase(.uppercase)
                                        .foregroundStyle(isSelected ? Chrome.moltenInk : Theme.Colors.textSecondary)
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(NineSlice(piece: isSelected ? Chrome.molten : Chrome.stonePressed, scale: 0.72))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                            }
                        }
                        .animation(.spring(duration: 0.25), value: settings.controlScheme)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier(AccessibilityID.Settings.controlPicker)
                        Text(settings.controlScheme == .drag
                             ? "The runner follows your finger anywhere on the screen."
                             : "Hold the left or right half of the screen to move.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    FlameDivider()

                    Toggle(isOn: $settings.hapticsEnabled) {
                        Label("Haptic feedback", systemImage: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .toggleStyle(StoneToggleStyle())
                    .onChange(of: settings.hapticsEnabled) { _, _ in viewModel.hapticsChanged() }
                    .accessibilityIdentifier(AccessibilityID.Settings.hapticsToggle)
                }

                settingsGroup(title: "Progress") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Reset progress")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Removes embers, upgrades, heroes and run history.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Button("Reset", role: .destructive, action: viewModel.requestReset)
                            .font(.display(15))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.Colors.danger)
                            .frame(minWidth: 92, minHeight: 44)
                            .background(NineSlice(piece: Chrome.stone, scale: 0.62))
                            .accessibilityIdentifier(AccessibilityID.Settings.resetButton)
                    }
                }

                settingsGroup(title: "About") {
                    aboutRow(title: "Version", value: viewModel.appVersion)
                    FlameDivider()
                    aboutRow(title: "Save data", value: "On this device")
                    FlameDivider()
                    Text("Magma Run stores your progress only on this device. No account, no tracking, no network.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(VolcanoBackdrop(emberCount: 12))
        .stoneNavigation("Settings")
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .confirmationDialog(
            "Reset all progress?",
            isPresented: $viewModel.isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Reset everything", role: .destructive, action: viewModel.confirmReset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Your embers, upgrades, unlocked heroes and records will be erased.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Settings.screen)
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.display(18))
                .foregroundStyle(Theme.Colors.ember)
                .textCase(.uppercase)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}
