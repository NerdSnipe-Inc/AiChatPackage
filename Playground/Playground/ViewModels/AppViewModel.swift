import Foundation
import AIChatCore
import AIChatOpenAI
import AIChatAnthropic
import AIChatLlama
import AIChatMLX
import AIChatFoundationModels
import AIChatUI
import FoundationModels
import JSONSchema

// MARK: - Demo descriptor

struct Demo: Identifiable {
    let id: String
    let provider: ProviderKind
    let title: String
    let subtitle: String
    let systemImage: String
    let badge: String?
    let config: Config

    enum ProviderKind: String, Hashable {
        case openai            = "OpenAI"
        case anthropic         = "Anthropic"
        case llamaServer       = "llama.cpp (server)"
        case llamaLocal        = "llama.cpp (local)"
        case mlx               = "MLX (on-device)"
        case foundationModels  = "Foundation Models"
    }

    // Config is not Hashable because ChatRequestOptions contains JSONSchema (not Hashable).
    // Demo itself is Hashable/Equatable via id only.
    enum Config {
        case chat(model: String, options: ChatRequestOptions)
        case llamaLocal
        case mlx
        case foundationModels
    }
}

extension Demo: Hashable {
    static func == (lhs: Demo, rhs: Demo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - ViewModel

@MainActor
@Observable
final class AppViewModel {

    // ── API keys — written through to UserDefaults immediately on change ─────
    var openAIKey: String = "" {
        didSet { UserDefaults.standard.set(openAIKey, forKey: "pg_openAIKey") }
    }
    var anthropicKey: String = "" {
        didSet { UserDefaults.standard.set(anthropicKey, forKey: "pg_anthropicKey") }
    }
    var llamaServerURL: String = "http://localhost:8080/v1/chat/completions" {
        didSet { UserDefaults.standard.set(llamaServerURL, forKey: "pg_llamaServerURL") }
    }

    // ── Demo catalogue ────────────────────────────────────────────────────
    let demos: [Demo]

    // ── Llama local model ─────────────────────────────────────────────────
    var localModelPath: String? {
        let url = Self.localModelFileURL
        return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
    }

    static let gemmaGGUFURL = URL(string:
        "https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF/resolve/main/google_gemma-4-E2B-it-Q4_K_M.gguf"
    )!

    static var localModelFileURL: URL {
        URL.applicationSupportDirectory
            .appending(component: "AIChatKitPlayground", directoryHint: .isDirectory)
            .appending(component: "google_gemma-4-E2B-it-Q4_K_M.gguf")
    }

    // ── Initialisation ────────────────────────────────────────────────────
    init() {
        self.demos = AppViewModel.buildDemos()
        load()
    }

    // MARK: - Provider factories

    func openAIProvider(streamUsage: Bool = true) -> OpenAIProvider {
        OpenAIProvider(apiKey: openAIKey, streamUsage: streamUsage)
    }

    func openAICompatibleProvider(urlString: String, streamUsage: Bool = false) -> OpenAIProvider? {
        guard let url = URL(string: urlString) else { return nil }
        return OpenAIProvider(apiKey: "", endpoint: url, streamUsage: streamUsage, id: "llama-server", name: "llama.cpp")
    }

    func anthropicProvider() -> AnthropicProvider {
        AnthropicProvider(apiKey: anthropicKey)
    }

    func llamaLocalProvider() -> LlamaProvider? {
        guard let path = localModelPath else { return nil }
        return LlamaProvider(modelPath: path, contextSize: 4096, nGpuLayers: 99)
    }

    // Single instance — model weights stay resident after first load so
    // returning to the sidebar item doesn't reload from disk each time.
    let mlxProvider = MLXProvider()

    // MARK: - Session cache

    /// One session per demo ID — persists conversations across sidebar switches.
    private var sessionCache: [String: ChatSession] = [:]

    /// Returns the cached session for this demo, creating one if needed.
    /// Returns nil when the required credential is missing or the feature is unavailable.
    func session(for demo: Demo) -> ChatSession? {
        if let existing = sessionCache[demo.id] { return existing }
        guard let fresh = makeSession(for: demo) else { return nil }
        sessionCache[demo.id] = fresh
        return fresh
    }

    /// Discards the cached session for a demo so the next call to session(for:) creates a fresh one.
    func resetSession(for demo: Demo) {
        sessionCache.removeValue(forKey: demo.id)
    }

    // MARK: - Session factory

    private func makeSession(for demo: Demo) -> ChatSession? {
        switch demo.config {
        case .chat(let model, let options):
            switch demo.provider {
            case .openai:
                guard !openAIKey.isEmpty else { return nil }
                return ChatSession(provider: openAIProvider(), model: model, options: options)
            case .anthropic:
                guard !anthropicKey.isEmpty else { return nil }
                return ChatSession(provider: anthropicProvider(), model: model, options: options)
            case .llamaServer:
                guard let provider = openAICompatibleProvider(urlString: llamaServerURL) else { return nil }
                return ChatSession(provider: provider, model: model, options: options)
            case .llamaLocal, .mlx, .foundationModels:
                return nil  // handled by dedicated views
            }

        case .llamaLocal:
            return nil  // handled by LlamaLocalView

        case .mlx:
            return nil  // handled by MLXLocalView

        case .foundationModels:
            if #available(macOS 26.0, iOS 26.0, *) {
                guard case .available = SystemLanguageModel.default.availability else { return nil }
                return ChatSession(
                    provider: FoundationModelsProvider(),
                    model: "",
                    options: ChatRequestOptions(systemPrompt: "You are a helpful assistant.")
                )
            }
            return nil
        }
    }

    // MARK: - Persistence

    func save() {
        UserDefaults.standard.set(openAIKey,      forKey: "pg_openAIKey")
        UserDefaults.standard.set(anthropicKey,   forKey: "pg_anthropicKey")
        UserDefaults.standard.set(llamaServerURL, forKey: "pg_llamaServerURL")
    }

    private func load() {
        openAIKey      = UserDefaults.standard.string(forKey: "pg_openAIKey")      ?? ""
        anthropicKey   = UserDefaults.standard.string(forKey: "pg_anthropicKey")   ?? ""
        llamaServerURL = UserDefaults.standard.string(forKey: "pg_llamaServerURL") ?? llamaServerURL
    }

    // MARK: - Demo catalogue builder

    private static func buildDemos() -> [Demo] {
        let weatherTool = ChatRequestOptions.ToolDefinition(
            name: "get_current_weather",
            description: "Get the current weather in a location.",
            parameters: .object(
                properties: [
                    "location": .string(description: "City and country, e.g. 'San Francisco, US'"),
                    "unit":     .enum(description: "Temperature unit", values: [.string("celsius"), .string("fahrenheit")]),
                ],
                required: ["location"]
            )
        )

        let bookTool = ChatRequestOptions.ToolDefinition(
            name: "recommend_book",
            description: "Recommend a book given a reference title and genre.",
            parameters: .object(
                properties: [
                    "reference": .string(description: "A book the user already likes"),
                    "genre":     .enum(description: "Genre", values: [.string("fiction"), .string("non-fiction")]),
                ],
                required: ["reference", "genre"]
            )
        )

        return [
            // ── OpenAI ────────────────────────────────────────────────────
            Demo(
                id: "openai-chat",
                provider: .openai,
                title: "Chat",
                subtitle: "Basic streaming chat",
                systemImage: "bubble.left.and.bubble.right",
                badge: nil,
                config: .chat(model: "gpt-4o", options: .init(temperature: 0.7))
            ),
            Demo(
                id: "openai-tools",
                provider: .openai,
                title: "Tool Use",
                subtitle: "Weather + book recommendation tools",
                systemImage: "wrench.and.screwdriver",
                badge: nil,
                config: .chat(model: "gpt-4o", options: .init(
                    tools: [weatherTool, bookTool],
                    toolChoice: .auto,
                    systemPrompt: "You are a helpful assistant. Use tools when appropriate."
                ))
            ),
            Demo(
                id: "openai-vision",
                provider: .openai,
                title: "Vision",
                subtitle: "Image understanding (paste an image URL)",
                systemImage: "eye",
                badge: nil,
                config: .chat(model: "gpt-4o", options: .init(
                    systemPrompt: "You are a vision assistant. Describe images clearly and concisely."
                ))
            ),
            Demo(
                id: "openai-reasoning",
                provider: .openai,
                title: "Reasoning",
                subtitle: "Extended reasoning with o3-mini",
                systemImage: "brain.head.profile",
                badge: "reasoning_effort",
                config: .chat(model: "o3-mini", options: .init(
                    reasoningEffort: "high",
                    systemPrompt: "Solve problems step by step."
                ))
            ),
            // ── Anthropic ─────────────────────────────────────────────────
            Demo(
                id: "anthropic-chat",
                provider: .anthropic,
                title: "Chat",
                subtitle: "Claude via Anthropic Messages API",
                systemImage: "bubble.left.and.bubble.right",
                badge: nil,
                config: .chat(model: "claude-sonnet-4-6", options: .init(temperature: 0.7))
            ),
            Demo(
                id: "anthropic-thinking",
                provider: .anthropic,
                title: "Extended Thinking",
                subtitle: "Collapsible reasoning tiles",
                systemImage: "brain",
                badge: "thinking",
                config: .chat(model: "claude-opus-4-8", options: .init(
                    maxTokens: 16000,
                    thinkingBudget: 8000,
                    systemPrompt: "Think carefully before answering. Show your reasoning."
                ))
            ),
            Demo(
                id: "anthropic-tools",
                provider: .anthropic,
                title: "Tool Use",
                subtitle: "Tool calls with multi-turn round-tripping",
                systemImage: "wrench.and.screwdriver",
                badge: nil,
                config: .chat(model: "claude-sonnet-4-6", options: .init(
                    tools: [weatherTool, bookTool],
                    toolChoice: .auto
                ))
            ),
            // ── llama.cpp server ──────────────────────────────────────────
            Demo(
                id: "llama-server",
                provider: .llamaServer,
                title: "llama-server",
                subtitle: "OpenAI-compatible local HTTP server",
                systemImage: "server.rack",
                badge: "HTTP",
                config: .chat(model: "local", options: .init(temperature: 0.8))
            ),
            // ── llama.cpp local ───────────────────────────────────────────
            Demo(
                id: "llama-local",
                provider: .llamaLocal,
                title: "Gemma 4 E2B",
                subtitle: "In-process inference via llama.cpp",
                systemImage: "cpu",
                badge: "in-process",
                config: .llamaLocal
            ),
            // ── Apple MLX ─────────────────────────────────────────────────
            Demo(
                id: "mlx-chat",
                provider: .mlx,
                title: "Gemma 4 E4B",
                subtitle: "Downloads ~2.5 GB on first use",
                systemImage: "memorychip",
                badge: "MLX",
                config: .mlx
            ),
            // ── Apple Foundation Models ───────────────────────────────────
            Demo(
                id: "foundation-models-chat",
                provider: .foundationModels,
                title: "Apple Intelligence",
                subtitle: "On-device via FoundationModels framework",
                systemImage: "apple.intelligence",
                badge: "macOS 26+",
                config: .foundationModels
            ),
        ]
    }
}
