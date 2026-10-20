import SwiftUI

@main
struct MagmaRunApp: App {
    private let bootstrap: Result<AppDependencies, Error>

    init() {
        bootstrap = Result { try AppDependencies() }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .success(let dependencies):
                RootView(dependencies: dependencies)
            case .failure(let error):
                StartupErrorView(message: error.localizedDescription)
            }
        }
    }
}

/// Shown only if the local database cannot be opened, which should never happen in practice.
struct StartupErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            VolcanoBackdrop()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Colors.ember)
                Text("The mountain is unreachable")
                    .font(.display(24))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Magma Run could not open its save data. Please restart the app. If the problem persists, reinstalling will create a fresh save.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: 480)
        }
        .preferredColorScheme(.dark)
    }
}
