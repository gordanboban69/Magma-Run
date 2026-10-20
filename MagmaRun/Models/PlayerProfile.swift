import Foundation
import SwiftData

/// The single persistent player profile: currency, upgrades, heroes and lifetime stats.
@Model
final class PlayerProfile {
    var embers: Int
    var bestScore: Int
    var totalRuns: Int
    var totalEmbersCollected: Int
    var totalBouldersDodged: Int
    var longestSurvival: TimeInterval

    var agilityLevel: Int
    var vitalityLevel: Int
    var shieldLevel: Int
    var magnetLevel: Int
    var fortuneLevel: Int

    var unlockedHeroIDs: [String]
    var selectedHeroID: String
    var createdAt: Date

    init(
        embers: Int = 0,
        bestScore: Int = 0,
        totalRuns: Int = 0,
        totalEmbersCollected: Int = 0,
        totalBouldersDodged: Int = 0,
        longestSurvival: TimeInterval = 0,
        agilityLevel: Int = 0,
        vitalityLevel: Int = 0,
        shieldLevel: Int = 0,
        magnetLevel: Int = 0,
        fortuneLevel: Int = 0,
        unlockedHeroIDs: [String] = [HeroSkin.starter.rawValue],
        selectedHeroID: String = HeroSkin.starter.rawValue,
        createdAt: Date = .now
    ) {
        self.embers = embers
        self.bestScore = bestScore
        self.totalRuns = totalRuns
        self.totalEmbersCollected = totalEmbersCollected
        self.totalBouldersDodged = totalBouldersDodged
        self.longestSurvival = longestSurvival
        self.agilityLevel = agilityLevel
        self.vitalityLevel = vitalityLevel
        self.shieldLevel = shieldLevel
        self.magnetLevel = magnetLevel
        self.fortuneLevel = fortuneLevel
        self.unlockedHeroIDs = unlockedHeroIDs
        self.selectedHeroID = selectedHeroID
        self.createdAt = createdAt
    }

    // MARK: - Derived values

    var selectedHero: HeroSkin {
        HeroSkin(rawValue: selectedHeroID) ?? .starter
    }

    func isUnlocked(_ skin: HeroSkin) -> Bool {
        skin.price == 0 || unlockedHeroIDs.contains(skin.rawValue)
    }

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .agility: agilityLevel
        case .vitality: vitalityLevel
        case .shield: shieldLevel
        case .magnet: magnetLevel
        case .fortune: fortuneLevel
        }
    }

    func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .agility: agilityLevel = level
        case .vitality: vitalityLevel = level
        case .shield: shieldLevel = level
        case .magnet: magnetLevel = level
        case .fortune: fortuneLevel = level
        }
    }

    /// The gameplay stats that the current upgrades and hero produce.
    var loadout: HeroLoadout {
        HeroLoadout(
            skin: selectedHero,
            agility: agilityLevel,
            vitality: vitalityLevel,
            shield: shieldLevel,
            magnet: magnetLevel,
            fortune: fortuneLevel
        )
    }

    /// Lightweight value snapshot used for achievement evaluation.
    var statsSnapshot: PlayerStats {
        PlayerStats(
            bestScore: bestScore,
            totalRuns: totalRuns,
            totalEmbersCollected: totalEmbersCollected,
            totalBouldersDodged: totalBouldersDodged,
            longestSurvival: longestSurvival,
            unlockedHeroCount: HeroSkin.allCases.filter { isUnlocked($0) }.count,
            maxedUpgradeCount: UpgradeKind.allCases.filter { level(for: $0) >= $0.maxLevel }.count
        )
    }
}
