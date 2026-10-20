import Foundation

/// The results of a finished run before they are persisted.
struct RunSummary: Equatable, Sendable {
    var score: Int
    var embersCollected: Int
    var duration: TimeInterval
    var bouldersDodged: Int
    var heroID: String
}

/// The outcome of persisting a run, including comparison with the previous best.
struct RunOutcome: Equatable, Sendable {
    var summary: RunSummary
    var previousBest: Int
    var isNewBest: Bool
    var totalEmbers: Int
}
