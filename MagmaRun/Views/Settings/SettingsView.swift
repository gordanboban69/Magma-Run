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
                        Picker("Controls", selection: $settings.controlScheme) {
                            ForEach(ControlScheme.allCases) { scheme in
                                Text(scheme.title).tag(scheme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier(AccessibilityID.Settings.controlPicker)
                        Text(settings.controlScheme == .drag
                             ? "The runner follows your finger anywhere on the screen."
                             : "Hold the left or right half of the screen to move.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Divider().overlay(Theme.Colors.stroke)

                    Toggle(isOn: $settings.hapticsEnabled) {
                        Label("Haptic feedback", systemImage: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .tint(Theme.Colors.lava)
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
                            .font(.display(14, weight: .bold))
                            .foregroundStyle(Theme.Colors.danger)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 14)
                            .background(Capsule().fill(Theme.Colors.danger.opacity(0.14)))
                            .accessibilityIdentifier(AccessibilityID.Settings.resetButton)
                    }
                }

                settingsGroup(title: "About") {
                    aboutRow(title: "Version", value: viewModel.appVersion)
                    Divider().overlay(Theme.Colors.stroke)
                    aboutRow(title: "Made with", value: "SwiftUI + SpriteKit")
                    Divider().overlay(Theme.Colors.stroke)
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
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
