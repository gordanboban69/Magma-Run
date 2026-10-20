import Foundation

/// The values the SwiftUI HUD displays, mirrored from the running scene.
struct GameHUDState: Equatable, Sendable {
    var score = 0
    var embers = 0
    var hearts: Int
    var maxHearts: Int
    var hasShield: Bool
    var shieldCharge: Double = 0
    var elapsed: TimeInterval = 0

    init(loadout: HeroLoadout) {
        hearts = loadout.maxHearts
        maxHearts = loadout.maxHearts
        hasShield = loadout.shieldRecharge != nil
        shieldCharge = hasShield ? 1 : 0
    }

    init(session: RunSession) {
        score = session.displayScore
        embers = session.embersCollected
        hearts = session.hearts
        maxHearts = session.loadout.maxHearts
        hasShield = session.hasShield
        shieldCharge = session.shieldCharge
        elapsed = session.elapsed
    }
}

/// Discrete gameplay moments the view model reacts to (haptics, flashes).
enum GameEvent: Equatable, Sendable {
    case emberCollected
    case shieldAbsorbed
    case damaged
    case defeated
}
