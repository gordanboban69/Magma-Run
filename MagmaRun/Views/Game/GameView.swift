import SpriteKit
import SwiftUI

/// Full-screen play view: SpriteKit scene underneath, SwiftUI HUD and overlays on top.
struct GameView: View {
    @State private var viewModel: GameViewModel
    let onQuit: (Route?) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var damageFlashOpacity: Double = 0

    init(viewModel: GameViewModel, onQuit: @escaping (Route?) -> Void) {
        self.viewModel = viewModel
        self.onQuit = onQuit
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if let scene = viewModel.scene {
                SpriteView(scene: scene, isPaused: viewModel.isScenePaused, preferredFramesPerSecond: 60)
                    .id(viewModel.sceneID)
                    .ignoresSafeArea()
            }

            damageVignette

            GameHUDView(
                hud: viewModel.hud,
                isVisible: viewModel.isRunning || viewModel.isScenePaused,
                onPause: viewModel.pause
            )

            if viewModel.controlScheme == .buttons, viewModel.isRunning {
                SteerControls(onSteer: viewModel.steer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            overlays
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Game.screen)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { viewModel.prepareScene() }
        .onDisappear { viewModel.tearDown() }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
        .onChange(of: viewModel.damageFlashCount) { _, _ in
            damageFlashOpacity = 1
            withAnimation(.easeOut(duration: 0.55)) {
                damageFlashOpacity = 0
            }
        }
    }

    private var damageVignette: some View {
        RadialGradient(
            colors: [.clear, Theme.Colors.magma.opacity(0.75)],
            center: .center,
            startRadius: 120,
            endRadius: 520
        )
        .ignoresSafeArea()
        .opacity(damageFlashOpacity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var overlays: some View {
        switch viewModel.phase {
        case .ready:
            ReadyOverlay(
                hero: viewModel.hero,
                loadout: viewModel.loadout,
                bestScore: viewModel.bestScore,
                controlScheme: viewModel.controlScheme,
                onStart: viewModel.beginRun,
                onQuit: { onQuit(nil) }
            )
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        case .countdown(let value):
            CountdownOverlay(value: value)
                .transition(.opacity)
        case .running:
            EmptyView()
        case .paused:
            PauseOverlay(
                score: viewModel.hud.score,
                onResume: viewModel.resume,
                onRestart: viewModel.restart,
                onQuit: { onQuit(nil) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .finished(let outcome):
            GameOverView(
                outcome: outcome,
                onPlayAgain: viewModel.restart,
                onForge: { onQuit(.forge) },
                onQuit: { onQuit(nil) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Two invisible touch zones for the button control scheme.
private struct SteerControls: View {
    let onSteer: (CGFloat) -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                steerZone(direction: -1, systemImage: "chevron.left", identifier: AccessibilityID.Game.steerLeft)
                steerZone(direction: 1, systemImage: "chevron.right", identifier: AccessibilityID.Game.steerRight)
            }
            .frame(height: 150)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func steerZone(direction: CGFloat, systemImage: String, identifier: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 30, weight: .black))
            .foregroundStyle(.white.opacity(0.35))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onSteer(direction) }
                    .onEnded { _ in onSteer(0) }
            )
            .accessibilityLabel(direction < 0 ? "Move left" : "Move right")
            .accessibilityIdentifier(identifier)
    }
}
