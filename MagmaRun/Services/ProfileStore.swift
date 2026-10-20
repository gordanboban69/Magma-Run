import Foundation
import SwiftData
import Observation

/// Errors surfaced to the interface when a purchase or selection is not possible.
enum ProfileError: LocalizedError, Equatable {
    case insufficientEmbers(needed: Int)
    case upgradeMaxed
    case heroAlreadyUnlocked
    case heroLocked

    var errorDescription: String? {
        switch self {
        case .insufficientEmbers(let needed):
            "You need \(Formatters.integer(needed)) more embers."
        case .upgradeMaxed:
            "This upgrade is already at its maximum level."
        case .heroAlreadyUnlocked:
            "This hero is already unlocked."
        case .heroLocked:
            "Unlock this hero before selecting it."
        }
    }
}

/// Owns the player's profile and run history on top of SwiftData.
/// All mutations go through here so views and view models never touch the model context.
@MainActor
@Observable
final class ProfileStore {
    private let context: ModelContext

    private(set) var profile: PlayerProfile
    private(set) var recentRuns: [RunRecord] = []
    /// Set when a save fails so the interface can tell the player.
    private(set) var persistenceErrorMessage: String?

    static let recentRunLimit = 25

    init(container: ModelContainer) throws {
        context = ModelContext(container)
        context.autosaveEnabled = false

        var descriptor = FetchDescriptor<PlayerProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            profile = existing
        } else {
            let created = PlayerProfile()
            context.insert(created)
            profile = created
            try context.save()
        }
        try reloadRuns()
    }

    // MARK: - Derived state

    var loadout: HeroLoadout { profile.loadout }

    var achievements: [Achievement] {
        AchievementCatalog.evaluate(profile.statsSnapshot)
    }

    func level(of kind: UpgradeKind) -> Int {
        profile.level(for: kind)
    }

    /// Cost of the next level, or `nil` when the upgrade is maxed.
    func nextCost(of kind: UpgradeKind) -> Int? {
        kind.cost(forLevel: profile.level(for: kind) + 1)
    }

    func canAfford(_ amount: Int) -> Bool {
        profile.embers >= amount
    }

    // MARK: - Mutations

    func purchaseUpgrade(_ kind: UpgradeKind) throws {
        guard let cost = nextCost(of: kind) else { throw ProfileError.upgradeMaxed }
        guard canAfford(cost) else {
            throw ProfileError.insufficientEmbers(needed: cost - profile.embers)
        }
        profile.embers -= cost
        profile.setLevel(profile.level(for: kind) + 1, for: kind)
        try save()
    }

    func unlockHero(_ skin: HeroSkin) throws {
        guard !profile.isUnlocked(skin) else { throw ProfileError.heroAlreadyUnlocked }
        guard canAfford(skin.price) else {
            throw ProfileError.insufficientEmbers(needed: skin.price - profile.embers)
        }
        profile.embers -= skin.price
        profile.unlockedHeroIDs.append(skin.rawValue)
        profile.selectedHeroID = skin.rawValue
        try save()
    }

    func selectHero(_ skin: HeroSkin) throws {
        guard profile.isUnlocked(skin) else { throw ProfileError.heroLocked }
        profile.selectedHeroID = skin.rawValue
        try save()
    }

    /// Stores a finished run, credits embers and updates lifetime statistics.
    @discardableResult
    func recordRun(_ summary: RunSummary) -> RunOutcome {
        let previousBest = profile.bestScore
        let isNewBest = summary.score > previousBest

        profile.embers += summary.embersCollected
        profile.totalRuns += 1
        profile.totalEmbersCollected += summary.embersCollected
        profile.totalBouldersDodged += summary.bouldersDodged
        profile.longestSurvival = max(profile.longestSurvival, summary.duration)
        if isNewBest {
            profile.bestScore = summary.score
        }

        context.insert(RunRecord(summary: summary))
        persistQuietly()
        pruneOldRuns()

        return RunOutcome(
            summary: summary,
            previousBest: previousBest,
            isNewBest: isNewBest,
            totalEmbers: profile.embers
        )
    }

    /// Deletes every run and restores the profile to its initial state.
    func resetProgress() throws {
        try context.delete(model: RunRecord.self)
        context.delete(profile)
        let fresh = PlayerProfile()
        context.insert(fresh)
        profile = fresh
        try save()
    }

    /// Grants embers without a run. Used only to seed deterministic UI-test sessions.
    func grantEmbers(_ amount: Int) throws {
        profile.embers += amount
        try save()
    }

    // MARK: - Persistence helpers

    private func save() throws {
        try context.save()
        try reloadRuns()
        persistenceErrorMessage = nil
    }

    private func persistQuietly() {
        do {
            try save()
        } catch {
            persistenceErrorMessage = "Progress could not be saved: \(error.localizedDescription)"
        }
    }

    private func reloadRuns() throws {
        var descriptor = FetchDescriptor<RunRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = Self.recentRunLimit
        recentRuns = try context.fetch(descriptor)
    }

    /// Keeps the history bounded so the store never grows unbounded.
    private func pruneOldRuns() {
        let descriptor = FetchDescriptor<RunRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let all = try? context.fetch(descriptor), all.count > Self.recentRunLimit else { return }
        for record in all.dropFirst(Self.recentRunLimit) {
            context.delete(record)
        }
        persistQuietly()
    }
}
