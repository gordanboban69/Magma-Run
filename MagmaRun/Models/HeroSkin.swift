import SwiftUI

/// A platform-independent RGB triple so the same palette can be used
/// by SwiftUI views and SpriteKit nodes.
struct RGB: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color { Color(red: red, green: green, blue: blue) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
}

/// Playable hero appearances. The first one is free; the rest are unlocked with embers.
enum HeroSkin: String, CaseIterable, Identifiable, Codable, Sendable {
    case ashRunner
    case emberScout
    case obsidianGhost
    case magmaTitan
    case crystalSpirit
    case phoenix

    var id: String { rawValue }

    static let starter: HeroSkin = .ashRunner

    var title: String {
        switch self {
        case .ashRunner: "Ash Runner"
        case .emberScout: "Ember Scout"
        case .obsidianGhost: "Obsidian Ghost"
        case .magmaTitan: "Magma Titan"
        case .crystalSpirit: "Crystal Spirit"
        case .phoenix: "Phoenix"
        }
    }

    var lore: String {
        switch self {
        case .ashRunner: "Born in the foothills, raised on falling rock."
        case .emberScout: "Carries a lantern of living flame."
        case .obsidianGhost: "Moves like smoke between the boulders."
        case .magmaTitan: "Forged in the deepest chamber of the mountain."
        case .crystalSpirit: "Glows with the light of volcanic glass."
        case .phoenix: "Rises again every time the mountain roars."
        }
    }

    /// Ember price to unlock. Zero means available from the start.
    var price: Int {
        switch self {
        case .ashRunner: 0
        case .emberScout: 150
        case .obsidianGhost: 350
        case .magmaTitan: 600
        case .crystalSpirit: 900
        case .phoenix: 1500
        }
    }

    var primary: RGB {
        switch self {
        case .ashRunner: RGB(red: 0.78, green: 0.76, blue: 0.80)
        case .emberScout: RGB(red: 1.0, green: 0.58, blue: 0.22)
        case .obsidianGhost: RGB(red: 0.22, green: 0.18, blue: 0.28)
        case .magmaTitan: RGB(red: 0.80, green: 0.18, blue: 0.14)
        case .crystalSpirit: RGB(red: 0.45, green: 0.85, blue: 0.95)
        case .phoenix: RGB(red: 1.0, green: 0.80, blue: 0.25)
        }
    }

    var secondary: RGB {
        switch self {
        case .ashRunner: RGB(red: 0.35, green: 0.33, blue: 0.40)
        case .emberScout: RGB(red: 0.55, green: 0.18, blue: 0.08)
        case .obsidianGhost: RGB(red: 0.60, green: 0.40, blue: 0.95)
        case .magmaTitan: RGB(red: 0.28, green: 0.05, blue: 0.05)
        case .crystalSpirit: RGB(red: 0.15, green: 0.40, blue: 0.60)
        case .phoenix: RGB(red: 0.90, green: 0.25, blue: 0.10)
        }
    }

    var glow: RGB {
        switch self {
        case .ashRunner: RGB(red: 1.0, green: 0.55, blue: 0.20)
        case .emberScout: RGB(red: 1.0, green: 0.85, blue: 0.40)
        case .obsidianGhost: RGB(red: 0.75, green: 0.55, blue: 1.0)
        case .magmaTitan: RGB(red: 1.0, green: 0.40, blue: 0.15)
        case .crystalSpirit: RGB(red: 0.70, green: 0.95, blue: 1.0)
        case .phoenix: RGB(red: 1.0, green: 0.60, blue: 0.10)
        }
    }
}
