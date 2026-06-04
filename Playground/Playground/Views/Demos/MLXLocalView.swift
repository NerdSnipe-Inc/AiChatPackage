import SwiftUI
import AIChatCore
import AIChatMLX
import AIChatUI

/// Shows model info and a Load button on first visit, then streams inference via
/// MLXProvider (Apple MLX, Apple Silicon only). The provider instance lives in
/// AppViewModel so the model weights stay resident across sidebar switches.
struct MLXLocalView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var phase: Phase = .idle

    enum Phase {
        case idle
        case loading(fractionCompleted: Double)
        case ready(session: ChatSession)
        case failed(String)
    }

    var body: some View {
        switch phase {
        case .idle:
            idleView
                .onAppear {
                    // Skip splash if model is already cached on disk —
                    // loadModel() will return immediately if already in memory.
                    if Self.isModelCached { load() }
                }

        case .loading(let fraction):
            loadingView(fraction: fraction)

        case .ready(let session):
            ChatView(session: session)
                .navigationTitle("Gemma 4 E4B")
                .navigationSubtitle("On-device · Apple MLX · Apple Silicon")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear") { session.clearHistory() }
                            .disabled(session.isGenerating)
                    }
                }

        case .failed(let message):
            failedView(message: message)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "memorychip")
                .font(.system(size: 52))
                .foregroundStyle(.teal)

            VStack(spacing: 6) {
                Text("Gemma 4 E4B IT")
                    .font(.title.bold())
                Text("mlx-community · 4-bit quantized · ~2.5 GB")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                featureRow("memorychip",     "Optimised for Apple Silicon via Apple MLX")
                featureRow("bolt.fill",      "Metal GPU and Neural Engine acceleration")
                featureRow("lock.shield",    "Fully private — data never leaves the device")
                featureRow("eye",            "Vision-capable model — supports image inputs")
            }
            .padding()
            .background(.secondary.opacity(0.06), in: .rect(cornerRadius: 12))

            Button(action: load) {
                Label("Load Model", systemImage: "arrow.down.circle")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)

            Text("~2.5 GB download on first use. Cached in the app sandbox.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.teal)
            Text(text)
                .font(.callout)
        }
    }

    // MARK: - Loading

    private func loadingView(fraction: Double) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "memorychip")
                .font(.system(size: 48))
                .foregroundStyle(.teal)
                .symbolEffect(.pulse)

            Text(fraction > 0 && fraction < 1 ? "Downloading Gemma 4 E4B…" : "Loading Gemma 4 E4B…")
                .font(.title3.bold())

            if fraction > 0 && fraction < 1 {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .frame(width: 320)
                    .tint(.teal)

                Text("\(Int(fraction * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.teal)
            }

            Button("Cancel") { phase = .idle }
                .buttonStyle(.bordered)
                .opacity(fraction > 0 && fraction < 1 ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Failed

    private func failedView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            Text("Failed to load model")
                .font(.title3.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") { phase = .idle }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Load

    private func load() {
        phase = .loading(fractionCompleted: 0)
        let provider = vm.mlxProvider
        Task {
            do {
                try await provider.loadModel { progress in
                    Task { @MainActor in
                        // fraction == 1 means download finished, model loading into memory
                        phase = .loading(fractionCompleted: progress.fractionCompleted)
                    }
                }
                let session = ChatSession(
                    provider: provider,
                    model: "",
                    options: .init(systemPrompt: "You are a helpful assistant running locally on this device.")
                )
                phase = .ready(session: session)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Cache check

    /// Returns true if the HuggingFace hub cache contains at least one snapshot
    /// of the default Gemma 4 E4B model, meaning the download can be skipped.
    private static var isModelCached: Bool {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return false }
        let snapshots = caches
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
            .appendingPathComponent("models--mlx-community--gemma-4-e4b-it-4bit")
            .appendingPathComponent("snapshots")
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: snapshots.path) else { return false }
        return !entries.isEmpty
    }
}
