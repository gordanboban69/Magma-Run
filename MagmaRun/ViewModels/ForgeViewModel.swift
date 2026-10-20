import Foundation
import Observation

/// Handles upgrade purchases and the feedback shown for them.
@MainActor
@Observable
final class ForgeViewModel {
    let store: ProfileStore
    private let haptics: HapticsService

    var toastMessage: String?
    var toastIsError = false
    /// Increments per upgrade to drive a shake animation on rejected purchases.
    private(set) var shakeCounts: [UpgradeKind: Int] = [:]
    /// Increments per upgrade to drive a success pulse.
    private(set) var pulseCounts: [UpgradeKind: Int] = [:]

    init(store: ProfileStore, haptics: HapticsService) {
        self.store = store
        self.haptics = haptics
    }

    var embers: Int { store.profile.embers }

    var maxedCount: Int {
        UpgradeKind.allCases.filter { store.level(of: $0) >= $0.maxLevel }.count
    }

    func level(of kind: UpgradeKind) -> Int { store.level(of: kind) }
    func nextCost(of kind: UpgradeKind) -> Int? { store.nextCost(of: kind) }

    func canPurchase(_ kind: UpgradeKind) -> Bool {
        guard let cost = store.nextCost(of: kind) else { return false }
        return store.canAfford(cost)
    }

    func purchase(_ kind: UpgradeKind) {
        do {
            try store.purchaseUpgrade(kind)
            pulseCounts[kind, default: 0] += 1
            haptics.notify(.success)
            show("\(kind.title) forged to level \(store.level(of: kind)).", isError: false)
        } catch {
            shakeCounts[kind, default: 0] += 1
            haptics.notify(.error)
            show(error.localizedDescription, isError: true)
        }
    }

    private func show(_ message: String, isError: Bool) {
        toastIsError = isError
        toastMessage = message
    }
}
