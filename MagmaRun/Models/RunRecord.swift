import Foundation
import SwiftData

/// A persisted record of one finished run, shown in the records screen.
@Model
final class RunRecord {
    var date: Date
    var score: Int
    var embersCollected: Int
    var duration: TimeInterval
    var bouldersDodged: Int
    var heroID: String

    init(summary: RunSummary, date: Date = .now) {
        self.date = date
        self.score = summary.score
        self.embersCollected = summary.embersCollected
        self.duration = summary.duration
        self.bouldersDodged = summary.bouldersDodged
        self.heroID = summary.heroID
    }

    var hero: HeroSkin {
        HeroSkin(rawValue: heroID) ?? .starter
    }
}
