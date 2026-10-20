import Foundation
import Observation

/// Backs the settings screen: preferences plus the destructive progress reset.
@MainActor
@Observable
final class SettingsViewModel {
    let settings: SettingsStore
    let store: ProfileStore
    private let haptics: HapticsService

    var isResetConfirmationPresented = false
    var toastMessage: String?
    var toastIsError = false

    init(settings: SettingsStore, store: ProfileStore, haptics: HapticsService) {
        self.settings = settings
        self.store = store
        self.haptics = haptics
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    func requestReset() {
        isResetConfirmationPresented = true
    }

    func confirmReset() {
        do {
            try store.resetProgress()
            haptics.notify(.warning)
            toastIsError = false
            toastMessage = "Progress reset. The mountain awaits."
        } catch {
            haptics.notify(.error)
            toastIsError = true
            toastMessage = "Could not reset progress: \(error.localizedDescription)"
        }
    }

    func hapticsChanged() {
        haptics.selection()
    }
}
