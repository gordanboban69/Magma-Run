import Foundation

/// How the player steers the hero during a run.
enum ControlScheme: String, CaseIterable, Identifiable, Codable, Sendable {
    /// The hero follows the finger anywhere on the screen.
    case drag
    /// Two on-screen buttons move the hero left and right.
    case buttons

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drag: "Follow finger"
        case .buttons: "Left / Right buttons"
        }
    }

    /// Short label for the settings switcher.
    var shortTitle: String {
        switch self {
        case .drag: "Drag"
        case .buttons: "Buttons"
        }
    }

    var systemImage: String {
        switch self {
        case .drag: "hand.draw.fill"
        case .buttons: "arrow.left.arrow.right.square.fill"
        }
    }
}
