import SwiftUI
import UIKit

@main
struct MagmaRunApp: App {
    private let bootstrap: Result<AppDependencies, Error>

    init() {
        bootstrap = Result { try AppDependencies() }
        Self.styleNavigationTitles()
    }

    /// Navigation titles use the game's chiselled display face in ember gold.
    private static func styleNavigationTitles() {
        let ember = UIColor(red: 1.0, green: 0.70, blue: 0.22, alpha: 1)
        let appearance = UINavigationBar.appearance()
        if let large = UIFont(name: "Futura-CondensedExtraBold", size: 36) {
            appearance.largeTitleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large),
                .foregroundColor: ember
            ]
        }
        if let inline = UIFont(name: "Futura-CondensedExtraBold", size: 20) {
            appearance.titleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline),
                .foregroundColor: ember
            ]
        }
        appearance.tintColor = ember
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
