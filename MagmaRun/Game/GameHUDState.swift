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

    /// Near-miss rage in `0...1`; a full bar discharges as a shockwave.
    var rage: Double = 0
    /// Current ember streak toward the next overdrive.
    var combo = 0
    var isOverdrive = false
    var overdriveRemaining: TimeInterval = 0
    var mood: VolcanoMood = .steady
    var upcomingMood: VolcanoMood?
    var moodRemaining: TimeInterval = 0
    var lavaWarning = false

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
        rage = session.rage
        combo = session.combo % RunSession.overdriveComboLength
        isOverdrive = session.isOverdrive
        overdriveRemaining = session.overdriveRemaining
        mood = session.mood
        upcomingMood = session.upcomingMood
        moodRemaining = session.moodRemaining
        lavaWarning = session.lavaRiver?.phase == .warning
    }
}

/// Discrete gameplay moments the view model reacts to (haptics, flashes).
enum GameEvent: Equatable, Sendable {
    case emberCollected
    case shieldAbsorbed
    case damaged
    case defeated
    case shockwave
    case overdriveStarted
    case moodChanged(VolcanoMood)
    case lavaStarted
}
