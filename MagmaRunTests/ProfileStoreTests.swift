import Foundation
import SwiftData
import Testing
@testable import MagmaRun

/// Persistence tests using an in-memory SwiftData container.
@MainActor
struct ProfileStoreTests {
    private func makeStore(container: ModelContainer? = nil) throws -> (ProfileStore, ModelContainer) {
        let container = try container ?? PersistenceController.makeContainer(inMemory: true)
        return (try ProfileStore(container: container), container)
    }

    @Test func freshProfileHasDefaults() throws {
        let (store, _) = try makeStore()
        #expect(store.profile.embers == 0)
        #expect(store.profile.bestScore == 0)
        #expect(store.profile.selectedHero == .starter)
        #expect(store.profile.isUnlocked(.starter))
        #expect(store.profile.isUnlocked(.phoenix) == false)
        #expect(store.recentRuns.isEmpty)
        #expect(store.loadout == .starter)
    }

    @Test func purchaseDeductsEmbersAndRaisesLevel() throws {
        let (store, _) = try makeStore()
        try store.grantEmbers(500)
        let cost = try #require(store.nextCost(of: .agility))

        try store.purchaseUpgrade(.agility)

        #expect(store.level(of: .agility) == 1)
        #expect(store.profile.embers == 500 - cost)
        #expect(store.loadout.agility == 1)
    }

    @Test func purchaseFailsWithoutEmbers() throws {
        let (store, _) = try makeStore()
        #expect(throws: ProfileError.insufficientEmbers(needed: UpgradeKind.agility.baseCost)) {
            try store.purchaseUpgrade(.agility)
        }
        #expect(store.level(of: .agility) == 0)
    }

    @Test func purchaseFailsWhenMaxed() throws {
        let (store, _) = try makeStore()
        try store.grantEmbers(100_000)
        for _ in 0..<UpgradeKind.vitality.maxLevel {
            try store.purchaseUpgrade(.vitality)
        }
        #expect(store.nextCost(of: .vitality) == nil)
        #expect(throws: ProfileError.upgradeMaxed) {
            try store.purchaseUpgrade(.vitality)
        }
    }

    @Test func unlockingHeroEquipsIt() throws {
        let (store, _) = try makeStore()
        try store.grantEmbers(HeroSkin.emberScout.price)

        try store.unlockHero(.emberScout)

        #expect(store.profile.embers == 0)
        #expect(store.profile.isUnlocked(.emberScout))
        #expect(store.profile.selectedHero == .emberScout)
        #expect(throws: ProfileError.heroAlreadyUnlocked) {
            try store.unlockHero(.emberScout)
        }
    }

    @Test func selectingLockedHeroFails() throws {
        let (store, _) = try makeStore()
        #expect(throws: ProfileError.heroLocked) {
            try store.selectHero(.phoenix)
        }
        try store.selectHero(.starter)
        #expect(store.profile.selectedHero == .starter)
    }

    @Test func recordingRunUpdatesStatsAndHistory() throws {
        let (store, _) = try makeStore()
        let summary = RunSummary(score: 1200, embersCollected: 40, duration: 65, bouldersDodged: 30, heroID: HeroSkin.starter.rawValue)

        let outcome = store.recordRun(summary)

        #expect(outcome.isNewBest)
        #expect(outcome.previousBest == 0)
        #expect(outcome.totalEmbers == 40)
        #expect(store.profile.bestScore == 1200)
        #expect(store.profile.totalRuns == 1)
        #expect(store.profile.totalEmbersCollected == 40)
        #expect(store.profile.totalBouldersDodged == 30)
        #expect(store.profile.longestSurvival == 65)
        #expect(store.recentRuns.count == 1)
        #expect(store.recentRuns.first?.score == 1200)

        let worse = store.recordRun(RunSummary(score: 300, embersCollected: 5, duration: 20, bouldersDodged: 4, heroID: HeroSkin.starter.rawValue))
        #expect(worse.isNewBest == false)
        #expect(worse.previousBest == 1200)
        #expect(store.profile.bestScore == 1200)
        #expect(store.profile.longestSurvival == 65)
        #expect(store.recentRuns.first?.score == 300)
    }

    @Test func historyIsPruned() throws {
        let (store, _) = try makeStore()
        for index in 0..<(ProfileStore.recentRunLimit + 5) {
            store.recordRun(RunSummary(score: index, embersCollected: 1, duration: 1, bouldersDodged: 0, heroID: HeroSkin.starter.rawValue))
        }
        #expect(store.recentRuns.count == ProfileStore.recentRunLimit)
        #expect(store.profile.totalRuns == ProfileStore.recentRunLimit + 5)
    }

    @Test func dataSurvivesReloadFromSameContainer() throws {
        let (first, container) = try makeStore()
        try first.grantEmbers(300)
        try first.purchaseUpgrade(.magnet)
        first.recordRun(RunSummary(score: 777, embersCollected: 9, duration: 30, bouldersDodged: 12, heroID: HeroSkin.starter.rawValue))

        let (second, _) = try makeStore(container: container)

        #expect(second.profile.embers == first.profile.embers)
        #expect(second.level(of: .magnet) == 1)
        #expect(second.profile.bestScore == 777)
        #expect(second.recentRuns.count == 1)
    }

    @Test func resetRestoresDefaults() throws {
        let (store, _) = try makeStore()
        try store.grantEmbers(1000)
        try store.purchaseUpgrade(.fortune)
        try store.unlockHero(.obsidianGhost)
        store.recordRun(RunSummary(score: 50, embersCollected: 2, duration: 5, bouldersDodged: 1, heroID: HeroSkin.starter.rawValue))

        try store.resetProgress()

        #expect(store.profile.embers == 0)
        #expect(store.level(of: .fortune) == 0)
        #expect(store.profile.selectedHero == .starter)
        #expect(store.profile.isUnlocked(.obsidianGhost) == false)
        #expect(store.profile.totalRuns == 0)
        #expect(store.recentRuns.isEmpty)
    }

    @Test func achievementsReflectProfile() throws {
        let (store, _) = try makeStore()
        #expect(store.achievements.allSatisfy { !$0.isUnlocked })

        store.recordRun(RunSummary(score: 1500, embersCollected: 10, duration: 70, bouldersDodged: 20, heroID: HeroSkin.starter.rawValue))

        let unlocked = Set(store.achievements.filter(\.isUnlocked).map(\.id))
        #expect(unlocked.contains("firstRun"))
        #expect(unlocked.contains("score1000"))
        #expect(unlocked.contains("survive60"))
        #expect(unlocked.contains("score5000") == false)
    }
}

/// Tests for achievement evaluation on plain value snapshots.
@MainActor
struct AchievementTests {
    @Test func emptyStatsUnlockNothing() {
        let achievements = AchievementCatalog.evaluate(PlayerStats())
        #expect(achievements.count == 9)
        #expect(achievements.allSatisfy { !$0.isUnlocked })
        // The starter hero is always owned, so "Collector" starts at one third.
        #expect(achievements.filter { $0.id != "heroes3" }.allSatisfy { $0.progress == 0 })
        let collector = try! #require(achievements.first { $0.id == "heroes3" })
        #expect(abs(collector.progress - 1.0 / 3.0) < 0.0001)
    }

    @Test func progressIsClampedAndUnlocksAtTarget() {
        var stats = PlayerStats()
        stats.totalBouldersDodged = 125
        let halfway = try! #require(AchievementCatalog.evaluate(stats).first { $0.id == "dodge250" })
        #expect(halfway.progress == 0.5)
        #expect(halfway.isUnlocked == false)

        stats.totalBouldersDodged = 10_000
        let done = try! #require(AchievementCatalog.evaluate(stats).first { $0.id == "dodge250" })
        #expect(done.progress == 1)
        #expect(done.isUnlocked)
    }
}

/// Tests for preference persistence.
@MainActor
struct SettingsStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "MagmaRunTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsAreSensible() {
        let settings = SettingsStore(defaults: makeDefaults())
        #expect(settings.hapticsEnabled)
        #expect(settings.controlScheme == .drag)
        #expect(settings.hasSeenHowToPlay == false)
    }

    @Test func valuesPersistAcrossInstances() {
        let defaults = makeDefaults()
        let first = SettingsStore(defaults: defaults)
        first.hapticsEnabled = false
        first.controlScheme = .buttons
        first.hasSeenHowToPlay = true

        let second = SettingsStore(defaults: defaults)
        #expect(second.hapticsEnabled == false)
        #expect(second.controlScheme == .buttons)
        #expect(second.hasSeenHowToPlay)
    }
}
