import Foundation

/// The resolved gameplay stats for a run, derived from the player's upgrade levels.
struct HeroLoadout: Equatable, Sendable {
    var skin: HeroSkin
    var agility: Int
    var vitality: Int
    var shield: Int
    var magnet: Int
    var fortune: Int

    static let starter = HeroLoadout(skin: .starter, agility: 0, vitality: 0, shield: 0, magnet: 0, fortune: 0)

    /// Horizontal movement speed in scene points per second.
    var moveSpeed: Double { 340 + 55 * Double(agility) }

    /// Number of hits the hero can take before the run ends.
    var maxHearts: Int { 3 + vitality }

    /// Seconds for the shield to recharge, or `nil` when the shield is not unlocked.
    var shieldRecharge: TimeInterval? {
        shield == 0 ? nil : 24 - 3 * Double(shield)
    }

    /// Distance in points at which embers start flying toward the hero. Zero disables the magnet.
    var magnetRadius: Double { magnet == 0 ? 0 : 60 + 28 * Double(magnet) }

    /// Currency awarded per ember pickup.
    var emberValue: Int { 1 + fortune }

    /// Seconds between ember drops during a run.
    var emberInterval: TimeInterval {
        GameBalance.emberSpawnInterval * (1 - 0.07 * Double(fortune))
    }

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .agility: agility
        case .vitality: vitality
        case .shield: shield
        case .magnet: magnet
        case .fortune: fortune
        }
    }

    mutating func setLevel(_ level: Int, for kind: UpgradeKind) {
        let clamped = min(max(level, 0), kind.maxLevel)
        switch kind {
        case .agility: agility = clamped
        case .vitality: vitality = clamped
        case .shield: shield = clamped
        case .magnet: magnet = clamped
        case .fortune: fortune = clamped
        }
    }
}
