import Foundation
import Observation

/// Handles unlocking and selecting hero skins.
@MainActor
@Observable
final class HeroesViewModel {
    enum Status: Equatable {
        case equipped
        case unlocked
        case locked(price: Int)
    }

    let store: ProfileStore
    private let haptics: HapticsService

    var toastMessage: String?
    var toastIsError = false
    private(set) var shakeCounts: [HeroSkin: Int] = [:]

    init(store: ProfileStore, haptics: HapticsService) {
        self.store = store
        self.haptics = haptics
    }

    var embers: Int { store.profile.embers }
    var selected: HeroSkin { store.profile.selectedHero }

    func status(of skin: HeroSkin) -> Status {
        if store.profile.selectedHero == skin { return .equipped }
        if store.profile.isUnlocked(skin) { return .unlocked }
        return .locked(price: skin.price)
    }

    func canUnlock(_ skin: HeroSkin) -> Bool {
        store.canAfford(skin.price)
    }

    /// Selects an unlocked hero or unlocks a locked one.
    func activate(_ skin: HeroSkin) {
        do {
            switch status(of: skin) {
            case .equipped:
                return
            case .unlocked:
                try store.selectHero(skin)
                haptics.selection()
                show("\(skin.title) is ready to run.", isError: false)
            case .locked:
                try store.unlockHero(skin)
                haptics.notify(.success)
                show("\(skin.title) unlocked and equipped.", isError: false)
            }
        } catch {
            shakeCounts[skin, default: 0] += 1
            haptics.notify(.error)
            show(error.localizedDescription, isError: true)
        }
    }

    private func show(_ message: String, isError: Bool) {
        toastIsError = isError
        toastMessage = message
    }
}
