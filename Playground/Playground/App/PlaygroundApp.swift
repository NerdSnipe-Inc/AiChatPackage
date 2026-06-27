import SwiftUI

@main
/// Entry point for the AIChatKit demo playground application.
struct PlaygroundApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(viewModel)
        }
        .defaultSize(width: 1100, height: 720)

        Settings {
            SettingsView()
                .environment(viewModel)
                .frame(width: 480)
        }
    }
}
