import Foundation

/// Accessibility identifiers shared between the app and its UI tests.
/// Keep the raw values in sync with `MyAppUITests`.
enum AccessibilityID {
    enum Home {
        static let screen = "home.screen"
        static let playButton = "home.play"
        static let forgeButton = "home.forge"
        static let heroesButton = "home.heroes"
        static let recordsButton = "home.records"
        static let howToPlayButton = "home.howToPlay"
        static let settingsButton = "home.settings"
        static let emberBalance = "home.emberBalance"
    }

    enum Game {
        static let screen = "game.screen"
        static let startButton = "game.start"
        static let pauseButton = "game.pause"
        static let resumeButton = "game.resume"
        static let restartButton = "game.restart"
        static let quitButton = "game.quit"
        static let scoreLabel = "game.score"
        static let pausedOverlay = "game.pausedOverlay"
        static let gameOverOverlay = "game.gameOverOverlay"
        static let steerLeft = "game.steerLeft"
        static let steerRight = "game.steerRight"
    }

    enum Forge {
        static let screen = "forge.screen"
        static func upgradeButton(_ id: String) -> String { "forge.upgrade.\(id)" }
    }

    enum Heroes {
        static let screen = "heroes.screen"
        static func heroCard(_ id: String) -> String { "heroes.card.\(id)" }
        static func heroAction(_ id: String) -> String { "heroes.action.\(id)" }
    }

    enum Records {
        static let screen = "records.screen"
        static let emptyState = "records.empty"
    }

    enum Settings {
        static let screen = "settings.screen"
        static let hapticsToggle = "settings.haptics"
        static let controlPicker = "settings.controls"
        static let resetButton = "settings.reset"
    }

    enum HowToPlay {
        static let screen = "howToPlay.screen"
    }
}
