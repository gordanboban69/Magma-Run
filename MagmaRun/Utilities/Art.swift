import Foundation

/// Names of the generated bitmaps in `Assets.xcassets/Generated`.
/// The art is painted by `Artwork/generate_assets.swift`; keep both in sync.
enum Art {
    static let logo = "logo_wordmark"
    static let homeBackdrop = "home_backdrop"
    static let panelTexture = "panel_texture"
    static let ember = "ember"
    static let emberIcon = "icon_ember"
    static let heartShard = "heart_shard"
    static let shieldBubble = "shield_bubble"
    static let shockwaveRing = "shockwave_ring"
    static let volcano = "volcano_mountain"
    static let groundTile = "ground_tile"
    static let lavaTile = "lava_tile"
    static let crustTile = "crust_tile"
    static let crackWarning = "crack_warning"
    static let badgeEarned = "badge_earned"
    static let badgeLocked = "badge_locked"

    /// Crater centre inside `volcano_mountain`, in points of the 600 × 760 image.
    static let volcanoSize = CGSize(width: 600, height: 760)
    static let volcanoCrater = CGPoint(x: 300, y: 46)

    static let craterBurstFrames = (0..<4).map { "crater_burst_\($0)" }
    static let rockChips = (0..<3).map { "rock_chip_\($0)" }
    static let boulderVariants = 4

    enum HUD {
        static let heartFull = "hud_heart_full"
        static let heartEmpty = "hud_heart_empty"
        static let shield = "hud_shield"
        static let rage = "hud_rage"
        static let overdrive = "hud_overdrive"
        static let shard = "hud_shard"
        static let crust = "hud_crust"
    }

    enum Menu {
        static let forge = "menu_forge"
        static let heroes = "menu_heroes"
        static let records = "menu_records"
        static let howTo = "menu_howto"
    }

    enum Tutorial {
        static let controls = "tutorial_controls"
        static let rage = "tutorial_rage"
        static let lava = "tutorial_lava"
        static let overdrive = "tutorial_overdrive"
        static let moods = "tutorial_moods"
        static let crust = "tutorial_crust"
        static let shards = "tutorial_shards"
    }

    static func heroRunFrames(_ skin: HeroSkin) -> [String] {
        (0..<4).map { "hero_\(skin.rawValue)_run_\($0)" }
    }

    static func heroPortrait(_ skin: HeroSkin) -> String {
        "hero_\(skin.rawValue)_portrait"
    }

    static func boulder(variant: Int, hot: Bool) -> String {
        let index = ((variant % boulderVariants) + boulderVariants) % boulderVariants
        return hot ? "boulder_hot_\(index)" : "boulder_\(index)"
    }

    static func upgrade(_ kind: UpgradeKind) -> String {
        "upgrade_\(kind.rawValue)"
    }

    static func sky(_ mood: VolcanoMood) -> String {
        "bg_sky_\(mood.artSuffix)"
    }

    static func mood(_ mood: VolcanoMood) -> String {
        "mood_\(mood.artSuffix)"
    }
}

private extension VolcanoMood {
    var artSuffix: String {
        switch self {
        case .steady: "steady"
        case .fury: "fury"
        case .ashRain: "ashrain"
        case .emberShower: "embershower"
        }
    }
}
