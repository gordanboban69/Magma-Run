import Foundation
import Observation
import SwiftUI

/// Drives one play session: countdown, running, pause and results.
/// Bridges the SpriteKit scene to SwiftUI state.
@MainActor
@Observable
final class GameViewModel {
    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case running
        case paused
        case finished(RunOutcome)
    }

    private(set) var phase: Phase = .ready
    private(set) var hud: GameHUDState
    /// Created lazily in `prepareScene()` so presenting the view is cheap.
    private(set) var scene: VolcanoScene?
    /// Changes whenever a fresh scene is created so SwiftUI rebuilds the `SpriteView`.
    private(set) var sceneID = UUID()
    /// Incremented on damage so the HUD can flash.
    private(set) var damageFlashCount = 0

    private let profileStore: ProfileStore
    private let settings: SettingsStore
    private let haptics: HapticsService
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    var controlScheme: ControlScheme { settings.controlScheme }
    var hero: HeroSkin { profileStore.loadout.skin }
    var loadout: HeroLoadout { profileStore.loadout }
    var bestScore: Int { profileStore.profile.bestScore }

    var isScenePaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    var isRunning: Bool { phase == .running }

    init(profileStore: ProfileStore, settings: SettingsStore, haptics: HapticsService) {
        self.profileStore = profileStore
        self.settings = settings
        self.haptics = haptics
        hud = GameHUDState(loadout: profileStore.loadout)
    }

    // MARK: - Scene management

    /// Builds the scene if it does not exist yet. Safe to call repeatedly.
    func prepareScene() {
        guard scene == nil else { return }
        installScene()
    }

    private func installScene() {
        scene?.gameDelegate = nil
        let loadout = profileStore.loadout
        hud = GameHUDState(loadout: loadout)
        let newScene = VolcanoScene(
            size: CGSize(width: 390, height: 844),
            loadout: loadout,
            controlScheme: settings.controlScheme
        )
        newScene.gameDelegate = self
        scene = newScene
        sceneID = UUID()
    }

    // MARK: - Intents

    /// Starts the 3-2-1 countdown and then the eruption.
    func beginRun() {
        guard phase == .ready else { return }
        prepareScene()
        haptics.prepare()
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for value in stride(from: 3, through: 1, by: -1) {
                guard let self, !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.3)) {
                    self.phase = .countdown(value)
                }
                self.haptics.impact(.light)
                try? await Task.sleep(for: .milliseconds(700))
            }
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.phase = .running
            }
            self.scene?.startRun()
        }
    }

    func pause() {
        guard phase == .running else { return }
        scene?.steeringDirection = 0
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .paused
        }
        haptics.selection()
    }

    func resume() {
        guard phase == .paused else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .running
        }
        haptics.selection()
    }

    /// Pauses automatically when the app leaves the foreground mid-run.
    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        guard scenePhase != .active else { return }
        if case .countdown = phase {
            countdownTask?.cancel()
            phase = .ready
        } else {
            pause()
        }
    }

    /// Creates a fresh scene with the latest upgrades and returns to the ready state.
    func restart() {
        countdownTask?.cancel()
        installScene()
        withAnimation(.easeOut(duration: 0.25)) {
            phase = .ready
        }
    }

    /// Steering input from the on-screen buttons.
    func steer(_ direction: CGFloat) {
        scene?.steeringDirection = direction
    }

    /// Releases the scene when the game screen goes away.
    func tearDown() {
        countdownTask?.cancel()
        scene?.gameDelegate = nil
        scene?.steeringDirection = 0
        scene = nil
    }
}

// MARK: - VolcanoSceneDelegate

extension GameViewModel: VolcanoSceneDelegate {
    func scene(_ scene: VolcanoScene, didUpdate hud: GameHUDState) {
        guard scene === self.scene else { return }
        self.hud = hud
    }

    func scene(_ scene: VolcanoScene, didRegister event: GameEvent) {
        guard scene === self.scene else { return }
        switch event {
        case .emberCollected:
            haptics.impact(.light)
        case .shieldAbsorbed:
            haptics.impact(.medium)
        case .damaged:
            damageFlashCount += 1
            haptics.impact(.heavy)
        case .defeated:
            damageFlashCount += 1
            haptics.notify(.error)
        }
    }

    func scene(_ scene: VolcanoScene, didFinishWith summary: RunSummary) {
        guard scene === self.scene else { return }
        let outcome = profileStore.recordRun(summary)
        withAnimation(.spring(duration: 0.45)) {
            phase = .finished(outcome)
        }
        if outcome.isNewBest {
            haptics.notify(.success)
        }
    }
}
