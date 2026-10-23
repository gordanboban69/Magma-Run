import Foundation

/// Tunable constants and formulas that drive the eruption difficulty curve.
/// All functions are pure so the balance can be unit tested.
enum GameBalance {
    /// Seconds between boulder launches at the very start of a run.
    static let initialSpawnInterval: TimeInterval = 1.4
    /// Seconds between boulder launches once the eruption reaches full intensity.
    static let minimumSpawnInterval: TimeInterval = 0.34
    /// Time needed for the eruption to reach full intensity.
    static let rampDuration: TimeInterval = 150
    /// Base interval between ember (currency) drops.
    static let emberSpawnInterval: TimeInterval = 2.2

    static let scorePerSecond: Double = 10
    static let scorePerEmber: Int = 25
    static let scorePerDodge: Int = 3

    /// How long the hero stays untouchable after taking damage.
    static let invulnerabilityDuration: TimeInterval = 1.4
    /// Brief grace period after the shield absorbs a hit.
    static let shieldGraceDuration: TimeInterval = 0.4
    /// Delay before the results screen appears after the final hit.
    static let gameOverDelay: TimeInterval = 0.9

    /// Eruption intensity in `0...1` for the given elapsed time (ease-out curve).
    static func intensity(at elapsed: TimeInterval) -> Double {
        let progress = min(max(elapsed / rampDuration, 0), 1)
        return 1 - pow(1 - progress, 2)
    }

    /// Seconds until the next boulder for the given elapsed time.
    static func spawnInterval(at elapsed: TimeInterval) -> TimeInterval {
        let range = initialSpawnInterval - minimumSpawnInterval
        return initialSpawnInterval - range * intensity(at: elapsed)
    }

    /// Multiplier applied to boulder launch speed.
    static func speedMultiplier(at elapsed: TimeInterval) -> Double {
        1 + 0.6 * intensity(at: elapsed)
    }

    /// Multiplier applied to passive score gain, rewarding survival late in a run.
    static func scoreMultiplier(at elapsed: TimeInterval) -> Double {
        1 + intensity(at: elapsed)
    }

    /// Probability that a boulder falls from the sky instead of erupting from the crater.
    static func rainProbability(at elapsed: TimeInterval) -> Double {
        0.45 * intensity(at: elapsed)
    }
}
