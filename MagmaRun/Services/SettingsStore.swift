import Foundation
import Observation

/// User preferences backed by `UserDefaults`.
@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let controlScheme = "settings.controlScheme"
        static let hasSeenHowToPlay = "settings.hasSeenHowToPlay"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    var controlScheme: ControlScheme {
        didSet { defaults.set(controlScheme.rawValue, forKey: Keys.controlScheme) }
    }

    /// Whether the tutorial has been shown before the first run.
    var hasSeenHowToPlay: Bool {
        didSet { defaults.set(hasSeenHowToPlay, forKey: Keys.hasSeenHowToPlay) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        controlScheme = ControlScheme(rawValue: defaults.string(forKey: Keys.controlScheme) ?? "") ?? .drag
        hasSeenHowToPlay = defaults.bool(forKey: Keys.hasSeenHowToPlay)
    }
}
