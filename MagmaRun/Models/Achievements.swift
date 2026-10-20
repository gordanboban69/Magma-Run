import Foundation

/// Value snapshot of lifetime statistics used to evaluate achievements.
struct PlayerStats: Equatable, Sendable {
    var bestScore = 0
    var totalRuns = 0
    var totalEmbersCollected = 0
    var totalBouldersDodged = 0
    var longestSurvival: TimeInterval = 0
    var totalShockwaves = 0
    var totalOverdrives = 0
    var unlockedHeroCount = 1
    var maxedUpgradeCount = 0
}

/// A milestone the player can reach through play.
struct Achievement: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let isUnlocked: Bool
    /// Progress in `0...1` toward unlocking.
    let progress: Double
}

/// Defines and evaluates all achievements. Evaluation is pure so it can be tested.
enum AchievementCatalog {
    private struct Definition {
        let id: String
        let title: String
        let detail: String
        let systemImage: String
        let target: Double
        let value: @Sendable (PlayerStats) -> Double
    }

    private static let definitions: [Definition] = [
        Definition(id: "firstRun", title: "First Eruption", detail: "Finish your first run.",
                   systemImage: "flag.checkered", target: 1) { Double($0.totalRuns) },
        Definition(id: "score1000", title: "Lava Walker", detail: "Score 1,000 points in a single run.",
                   systemImage: "flame", target: 1000) { Double($0.bestScore) },
        Definition(id: "score5000", title: "Crater Legend", detail: "Score 5,000 points in a single run.",
                   systemImage: "crown.fill", target: 5000) { Double($0.bestScore) },
        Definition(id: "survive60", title: "One Minute of Fire", detail: "Survive for 60 seconds.",
                   systemImage: "timer", target: 60) { $0.longestSurvival },
        Definition(id: "dodge250", title: "Untouchable", detail: "Dodge 250 boulders in total.",
                   systemImage: "figure.run", target: 250) { Double($0.totalBouldersDodged) },
        Definition(id: "embers500", title: "Ember Hoarder", detail: "Collect 500 embers in total.",
                   systemImage: "sparkles", target: 500) { Double($0.totalEmbersCollected) },
        Definition(id: "runs25", title: "Mountain Regular", detail: "Finish 25 runs.",
                   systemImage: "repeat", target: 25) { Double($0.totalRuns) },
        Definition(id: "shockwaves10", title: "Earthshaker", detail: "Unleash 10 rage shockwaves.",
                   systemImage: "dot.radiowaves.left.and.right", target: 10) { Double($0.totalShockwaves) },
        Definition(id: "overdrives5", title: "Molten Heart", detail: "Enter overdrive 5 times.",
                   systemImage: "bolt.heart.fill", target: 5) { Double($0.totalOverdrives) },
        Definition(id: "heroes3", title: "Collector", detail: "Unlock 3 heroes.",
                   systemImage: "person.3.fill", target: 3) { Double($0.unlockedHeroCount) },
        Definition(id: "maxUpgrade", title: "Master Smith", detail: "Max out any upgrade.",
                   systemImage: "hammer.fill", target: 1) { Double($0.maxedUpgradeCount) }
    ]

    static func evaluate(_ stats: PlayerStats) -> [Achievement] {
        definitions.map { definition in
            let value = definition.value(stats)
            let progress = min(max(value / definition.target, 0), 1)
            return Achievement(
                id: definition.id,
                title: definition.title,
                detail: definition.detail,
                systemImage: definition.systemImage,
                isUnlocked: value >= definition.target,
                progress: progress
            )
        }
    }
}
