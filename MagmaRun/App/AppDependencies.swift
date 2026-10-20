import Foundation
import SwiftData

/// Composition root: builds the stores and services the whole app shares.
@MainActor
final class AppDependencies {
    let container: ModelContainer
    let profileStore: ProfileStore
    let settings: SettingsStore
    let haptics: HapticsService
    let isUITesting: Bool

    static let uiTestingArgument = "--uitesting"
    private static let uiTestingDefaultsSuite = "com.lumeridge.kestrelpath.uitesting"

    init(launchArguments: [String] = CommandLine.arguments) throws {
        isUITesting = launchArguments.contains(Self.uiTestingArgument)

        let defaults: UserDefaults
        if isUITesting, let suite = UserDefaults(suiteName: Self.uiTestingDefaultsSuite) {
            suite.removePersistentDomain(forName: Self.uiTestingDefaultsSuite)
            defaults = suite
        } else {
            defaults = .standard
        }

        container = try PersistenceController.makeContainer(inMemory: isUITesting)
        profileStore = try ProfileStore(container: container)
        settings = SettingsStore(defaults: defaults)

        let settings = self.settings
        haptics = HapticsService { settings.hapticsEnabled }

        if isUITesting {
            // Deterministic state so UI tests can exercise purchases without playing.
            settings.hasSeenHowToPlay = true
            try profileStore.grantEmbers(1000)
        }
    }
}
