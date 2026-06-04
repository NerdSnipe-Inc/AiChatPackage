import SwiftUI
import AIChatCore
import AIChatLlama
import AIChatUI

/// Downloads Gemma 4 E2B IT (Q4_K_M, ~3.5 GB) on first launch, then shows a full
/// ChatView backed by LlamaProvider running inference in-process on the device GPU.
struct LlamaLocalView: View {
    @Environment(AppViewModel.self) private var vm
    @State private var phase: Phase = .idle
    @State private var progressObservation: NSKeyValueObservation?

    enum Phase {
        case idle
        case downloading(progress: Double, bytesReceived: Int64, totalBytes: Int64)
        case ready(session: ChatSession)
        case failed(String)
    }

    var body: some View {
        switch phase {
        case .idle:
            idleView
                .onAppear {
                    // If the model is already on disk, go straight to the chat —
                    // don't show the download screen on every sidebar re-selection.
                    if vm.localModelPath != nil { launch() }
                }

        case .downloading(let progress, let received, let total):
            downloadingView(progress: progress, received: received, total: total)

        case .ready(let session):
            ChatView(session: session)
                .navigationTitle("Gemma 4 E2B")
                .navigationSubtitle("In-process · llama.cpp · Metal GPU")
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
            Image(systemName: "cpu")
                .font(.system(size: 52))
                .foregroundStyle(.purple)

            VStack(spacing: 6) {
                Text("Gemma 4 E2B IT")
                    .font(.title.bold())
                Text("Google · Q4_K_M · ~3.5 GB")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                featureRow("cpu",            "Runs entirely on-device — no network calls")
                featureRow("memorychip",     "Metal GPU acceleration via llama.cpp")
                featureRow("lock.shield",    "Fully private — data never leaves the Mac")
                featureRow("textformat.abc", "Built-in Gemma 4 chat template applied automatically")
            }
            .padding()
            .background(.secondary.opacity(0.06), in: .rect(cornerRadius: 12))

            Button(action: startDownload) {
                Label("Download Model", systemImage: "arrow.down.circle")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.purple)

            Text("Requires ~3.5 GB of free disk space.")
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
                .foregroundStyle(.purple)
            Text(text)
                .font(.callout)
        }
    }

    // MARK: - Downloading

    private func downloadingView(progress: Double, received: Int64, total: Int64) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
                .symbolEffect(.pulse)

            Text("Downloading Gemma 4 E2B…")
                .font(.title3.bold())

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 320)
                .tint(.purple)

            Text("\(formatBytes(received)) / \(formatBytes(total))  ·  \(Int(progress * 100))%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Button("Cancel") { phase = .idle }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Failed

    private func failedView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            Text("Download failed")
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

    // MARK: - Actions

    private func launch() {
        guard let provider = vm.llamaLocalProvider() else {
            phase = .failed("Model file missing from expected path. Please re-download.")
            return
        }
        let session = ChatSession(
            provider: provider,
            model: "local",
            options: .init(
                maxTokens: 512,
                temperature: 0.7,
                systemPrompt: "You are a helpful assistant running locally on this device."
            )
        )
        phase = .ready(session: session)
    }

    private func startDownload() {
        let dest = AppViewModel.localModelFileURL
        try? FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let task = URLSession.shared.downloadTask(with: AppViewModel.gemmaGGUFURL) { tempURL, _, error in
            DispatchQueue.main.async {
                if let error { phase = .failed(error.localizedDescription); return }
                guard let tempURL else { phase = .failed("No file received."); return }
                do {
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    launch()
                } catch {
                    phase = .failed(error.localizedDescription)
                }
            }
        }

        progressObservation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                phase = .downloading(
                    progress:      progress.fractionCompleted,
                    bytesReceived: progress.completedUnitCount,
                    totalBytes:    progress.totalUnitCount
                )
            }
        }

        phase = .downloading(progress: 0, bytesReceived: 0, totalBytes: 0)
        task.resume()
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
