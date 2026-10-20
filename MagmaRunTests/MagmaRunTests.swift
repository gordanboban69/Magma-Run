import Foundation
import Testing
@testable import MagmaRun

/// Tests for the pure difficulty curve.
@MainActor
struct GameBalanceTests {
    @Test func intensityStartsAtZeroAndCapsAtOne() {
        #expect(GameBalance.intensity(at: 0) == 0)
        #expect(GameBalance.intensity(at: GameBalance.rampDuration) == 1)
        #expect(GameBalance.intensity(at: GameBalance.rampDuration * 3) == 1)
        #expect(GameBalance.intensity(at: -10) == 0)
    }

    @Test func intensityIsMonotonic() {
        var previous = GameBalance.intensity(at: 0)
        for second in stride(from: 1.0, through: GameBalance.rampDuration, by: 1.0) {
            let current = GameBalance.intensity(at: second)
            #expect(current >= previous)
            previous = current
        }
    }

    @Test func spawnIntervalShrinksWithinBounds() {
        let start = GameBalance.spawnInterval(at: 0)
        let middle = GameBalance.spawnInterval(at: GameBalance.rampDuration / 2)
        let end = GameBalance.spawnInterval(at: GameBalance.rampDuration)
        #expect(start == GameBalance.initialSpawnInterval)
        #expect(middle < start)
        #expect(end < middle)
        #expect(abs(end - GameBalance.minimumSpawnInterval) < 0.0001)
    }

    @Test func multipliersGrowWithIntensity() {
        #expect(GameBalance.speedMultiplier(at: 0) == 1)
        #expect(GameBalance.speedMultiplier(at: GameBalance.rampDuration) > 1.5)
        #expect(GameBalance.scoreMultiplier(at: 0) == 1)
        #expect(GameBalance.scoreMultiplier(at: GameBalance.rampDuration) == 2)
        #expect(GameBalance.rainProbability(at: 0) == 0)
        #expect(GameBalance.rainProbability(at: GameBalance.rampDuration) < 0.5)
    }
}

/// Tests for upgrade pricing and the stats they produce.
@MainActor
struct UpgradeTests {
    @Test(arguments: UpgradeKind.allCases)
    func costsRiseAndStopAtMaxLevel(kind: UpgradeKind) {
        var previous = 0
        for level in 1...kind.maxLevel {
            let cost = try! #require(kind.cost(forLevel: level))
            #expect(cost > previous)
            #expect(cost % 5 == 0)
            previous = cost
        }
        #expect(kind.cost(forLevel: 0) == nil)
        #expect(kind.cost(forLevel: kind.maxLevel + 1) == nil)
    }

    @Test func starterLoadoutMatchesDesign() {
        let loadout = HeroLoadout.starter
        #expect(loadout.maxHearts == 3)
        #expect(loadout.shieldRecharge == nil)
        #expect(loadout.magnetRadius == 0)
        #expect(loadout.emberValue == 1)
        #expect(loadout.moveSpeed == 340)
    }

    @Test func levelsChangeStats() {
        var loadout = HeroLoadout.starter
        loadout.setLevel(2, for: .vitality)
        loadout.setLevel(1, for: .shield)
        loadout.setLevel(3, for: .magnet)
        loadout.setLevel(4, for: .fortune)
        loadout.setLevel(5, for: .agility)

        #expect(loadout.maxHearts == 5)
        #expect(loadout.shieldRecharge == 21)
        #expect(loadout.magnetRadius == 144)
        #expect(loadout.emberValue == 5)
        #expect(loadout.moveSpeed == 615)
        #expect(loadout.emberInterval < GameBalance.emberSpawnInterval)
    }

    @Test func setLevelClampsToRange() {
        var loadout = HeroLoadout.starter
        loadout.setLevel(99, for: .agility)
        #expect(loadout.agility == UpgradeKind.agility.maxLevel)
        loadout.setLevel(-3, for: .agility)
        #expect(loadout.agility == 0)
    }

    @Test func effectDescriptionsAreHumanReadable() {
        #expect(UpgradeKind.shield.effectDescription(atLevel: 0) == "No shield")
        #expect(UpgradeKind.shield.effectDescription(atLevel: 5) == "Recharge 9s")
        #expect(UpgradeKind.vitality.effectDescription(atLevel: 1) == "4 hearts")
        #expect(UpgradeKind.magnet.effectDescription(atLevel: 0) == "Touch only")
        #expect(UpgradeKind.fortune.effectDescription(atLevel: 2) == "x3 embers")
    }
}
