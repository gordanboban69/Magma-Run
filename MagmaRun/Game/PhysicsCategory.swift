import Foundation

/// Bit masks for SpriteKit physics bodies.
enum PhysicsCategory {
    static let none: UInt32 = 0
    static let hero: UInt32 = 1 << 0
    static let boulder: UInt32 = 1 << 1
    static let ember: UInt32 = 1 << 2
}

/// Rendering order of the scene layers.
enum SceneLayer {
    static let background: CGFloat = -100
    static let craterGlow: CGFloat = -90
    static let mountain: CGFloat = -80
    static let ash: CGFloat = -60
    static let ground: CGFloat = -40
    static let embers: CGFloat = 10
    static let hero: CGFloat = 20
    static let boulders: CGFloat = 30
    static let effects: CGFloat = 40
}
