import SwiftUI
import AIChatCore
import AIChatUI

struct RootView: View {
    @Environment(AppViewModel.self) private var vm
    @Environment(\.openSettings) private var openSettings
    @State private var selectedDemo: Demo?

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                .navigationTitle("AIChatKit")
        } detail: {
            detail
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedDemo) {
            ForEach(Demo.ProviderKind.allCases, id: \.self) { provider in
                let providerDemos = vm.demos.filter { $0.provider == provider }
                if !providerDemos.isEmpty {
                    Section(provider.rawValue) {
                        ForEach(providerDemos) { demo in
                            DemoRow(demo: demo)
                                .tag(demo)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let demo = selectedDemo {
            if case .llamaLocal = demo.config {
                LlamaLocalView()
            } else if let session = vm.session(for: demo) {
                ChatDemoView(demo: demo, session: session)
                    .id(demo.id)
            } else {
                unavailableView(for: demo)
            }
        } else {
            welcomeView
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("AIChatKit Playground")
                .font(.largeTitle.bold())
            Text("Select a demo from the sidebar.\nConfigure API keys in Settings (⌘,).")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    // MARK: - Unavailable / credential required

    @ViewBuilder
    private func unavailableView(for demo: Demo) -> some View {
        switch demo.provider {
        case .foundationModels:
            foundationModelsUnavailableView
        default:
            credentialRequired(for: demo)
        }
    }

    private var foundationModelsUnavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Apple Intelligence required")
                .font(.title2.bold())
            if #available(macOS 26.0, iOS 26.0, *) {
                Text("Enable Apple Intelligence in System Settings → Apple Intelligence & Siri.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Requires macOS 26 or iOS 26 with Apple Intelligence enabled.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func credentialRequired(for demo: Demo) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("API key required")
                .font(.title2.bold())
            Text("Add your \(demo.provider.rawValue) API key to start chatting.")
                .foregroundStyle(.secondary)
            Button(action: { openSettings() }) {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(",", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Demo.ProviderKind: CaseIterable {
    static var allCases: [Demo.ProviderKind] {
        [.openai, .anthropic, .llamaServer, .llamaLocal, .mlx, .foundationModels]
    }
}
