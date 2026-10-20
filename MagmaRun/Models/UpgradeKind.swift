import Foundation

/// The permanent hero upgrades that can be forged with embers.
enum UpgradeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case agility
    case vitality
    case shield
    case magnet
    case fortune

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agility: "Agility"
        case .vitality: "Vitality"
        case .shield: "Obsidian Shield"
        case .magnet: "Ember Magnet"
        case .fortune: "Fortune"
        }
    }

    var summary: String {
        switch self {
        case .agility: "Move faster to slip between falling boulders."
        case .vitality: "Extra hearts let you survive more direct hits."
        case .shield: "A recharging shield that absorbs one hit."
        case .magnet: "Pulls nearby embers toward you."
        case .fortune: "Every ember is worth more and drops more often."
        }
    }

    var systemImage: String {
        switch self {
        case .agility: "hare.fill"
        case .vitality: "heart.fill"
        case .shield: "shield.lefthalf.filled"
        case .magnet: "sparkles"
        case .fortune: "flame.fill"
        }
    }

    var maxLevel: Int {
        switch self {
        case .agility: 5
        case .vitality: 3
        case .shield: 5
        case .magnet: 5
        case .fortune: 5
        }
    }

    var baseCost: Int {
        switch self {
        case .agility: 60
        case .vitality: 110
        case .shield: 130
        case .magnet: 70
        case .fortune: 90
        }
    }

    /// Ember cost to reach `level` (1-based). Returns `nil` when `level` is out of range.
    func cost(forLevel level: Int) -> Int? {
        guard level >= 1, level <= maxLevel else { return nil }
        let raw = Double(baseCost) * pow(1.65, Double(level - 1))
        // Round to a friendly multiple of five.
        return Int((raw / 5).rounded()) * 5
    }

    /// Human readable effect at a given level, e.g. "Speed 395".
    func effectDescription(atLevel level: Int) -> String {
        var loadout = HeroLoadout.starter
        loadout.setLevel(level, for: self)
        switch self {
        case .agility:
            return "Speed \(Int(loadout.moveSpeed))"
        case .vitality:
            return "\(loadout.maxHearts) hearts"
        case .shield:
            if let recharge = loadout.shieldRecharge {
                return "Recharge \(Int(recharge))s"
            }
            return "No shield"
        case .magnet:
            return loadout.magnetRadius > 0 ? "Radius \(Int(loadout.magnetRadius))" : "Touch only"
        case .fortune:
            return "x\(loadout.emberValue) embers"
        }
    }
}
