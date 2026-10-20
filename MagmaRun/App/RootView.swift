import SwiftUI

/// Hosts navigation, presents the game full screen and wires dependencies into the environment.
struct RootView: View {
    let dependencies: AppDependencies

    @State private var path: [Route] = []
    @State private var isPlaying = false
    @State private var isOnboardingPresented = false
    @State private var shouldPlayAfterOnboarding = false
    @State private var routeAfterGame: Route?

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onPlay: requestPlay)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .tint(Theme.Colors.ember)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $isPlaying, onDismiss: handleGameDismissed) {
            GameView(
                viewModel: GameViewModel(
                    profileStore: dependencies.profileStore,
                    settings: dependencies.settings,
                    haptics: dependencies.haptics
                ),
                onQuit: { route in
                    routeAfterGame = route
                    isPlaying = false
                }
            )
        }
        .sheet(isPresented: $isOnboardingPresented, onDismiss: handleOnboardingDismissed) {
            HowToPlayView(isOnboarding: true) {
                dependencies.settings.hasSeenHowToPlay = true
                shouldPlayAfterOnboarding = true
                isOnboardingPresented = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .environment(dependencies.profileStore)
        .environment(dependencies.settings)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .forge:
            ForgeView(viewModel: ForgeViewModel(store: dependencies.profileStore, haptics: dependencies.haptics))
        case .heroes:
            HeroesView(viewModel: HeroesViewModel(store: dependencies.profileStore, haptics: dependencies.haptics))
        case .records:
            RecordsView()
        case .howToPlay:
            HowToPlayView(isOnboarding: false, onContinue: nil)
        case .settings:
            SettingsView(viewModel: SettingsViewModel(
                settings: dependencies.settings,
                store: dependencies.profileStore,
                haptics: dependencies.haptics
            ))
        }
    }

    private func requestPlay() {
        if dependencies.settings.hasSeenHowToPlay {
            isPlaying = true
        } else {
            isOnboardingPresented = true
        }
    }

    private func handleOnboardingDismissed() {
        guard shouldPlayAfterOnboarding else { return }
        shouldPlayAfterOnboarding = false
        isPlaying = true
    }

    private func handleGameDismissed() {
        guard let route = routeAfterGame else { return }
        routeAfterGame = nil
        path = [route]
    }
}
