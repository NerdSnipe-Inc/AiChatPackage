# AIChatKit

A Swift package providing a unified chat interface across cloud and on-device AI providers. OpenAI, Anthropic, and llama.cpp local inference all share the same protocol, message model, and SwiftUI components.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNerdSnipe-Inc%2FAiChatPackage%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/NerdSnipe-Inc/AiChatPackage)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNerdSnipe-Inc%2FAiChatPackage%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/NerdSnipe-Inc/AiChatPackage)

**Platforms:** macOS 14+ · iOS 17+  
**Language:** Swift 5.10+

---

## Products

| Product | Description |
|---|---|
| `AIChatCore` | Protocols, message model, shared types |
| `AIChatOpenAI` | OpenAI-compatible provider (OpenAI, OpenRouter, llama-server, …) |
| `AIChatAnthropic` | Anthropic Messages API provider with extended thinking support |
| `AIChatLlama` | In-process llama.cpp inference with Metal GPU acceleration |
| `AIChatUI` | Drop-in SwiftUI chat interface |

Add only what you need. `AIChatLlama` pulls a large XCFramework (~500 MB); omit it for cloud-only targets.

---

## Installation

```swift
// Package.swift
.package(
    url: "https://github.com/NerdSnipe-Inc/AiChatPackage",
    from: "1.0.0"
)
```

Add the specific products your target requires:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "AIChatCore",      package: "AiChatPackage"),
        .product(name: "AIChatOpenAI",    package: "AiChatPackage"),
        .product(name: "AIChatAnthropic", package: "AiChatPackage"),
        .product(name: "AIChatUI",        package: "AiChatPackage"),
        // Add AIChatLlama only when you need on-device inference:
        .product(name: "AIChatLlama",     package: "AiChatPackage"),
    ]
)
```

---

## Quick Start

### SwiftUI — drop-in chat view

```swift
import SwiftUI
import AIChatOpenAI
import AIChatUI

struct ContentView: View {
    @StateObject private var session = ChatSession(
        provider: OpenAIProvider(apiKey: "sk-…"),
        model: "gpt-4o",
        options: ChatRequestOptions(temperature: 0.7)
    )

    var body: some View {
        ChatView(session: session)
    }
}
```

`ChatView` handles streaming text, reasoning tiles, tool call display, and error banners. `ChatSession` owns the conversation history.

---

## Providers

### OpenAI

```swift
import AIChatOpenAI

// OpenAI
let provider = OpenAIProvider(apiKey: "sk-…")

// Any OpenAI-compatible endpoint (OpenRouter, llama-server, etc.)
let provider = OpenAIProvider(
    apiKey: "your-key",
    endpoint: URL(string: "https://openrouter.ai/api/v1/chat/completions")!
)

// Local llama-server (no auth, stream_options not supported)
let provider = OpenAIProvider(
    apiKey: "",
    endpoint: URL(string: "http://localhost:8080/v1/chat/completions")!,
    streamUsage: false
)
```

### Anthropic

```swift
import AIChatAnthropic

let provider = AnthropicProvider(apiKey: "sk-ant-…")
```

Supports streaming text, extended thinking (Claude 3.5+), and tool use out of the box.

### llama.cpp — on-device inference

```swift
import AIChatLlama

let provider = LlamaProvider(
    modelPath: "/path/to/model.gguf",
    contextSize: 8192,   // KV cache window
    nGpuLayers: 99       // 99 = all layers on Metal GPU; -1 = CPU only
)
```

The model loads once on first use and stays resident. A persistent KV cache is reused across turns — only new tokens are evaluated each request.

---

## Sessions

`ChatSession` is an `ObservableObject` that drives the UI and manages conversation history.

```swift
let session = ChatSession(
    provider: provider,
    model: "gpt-4o",           // ignored by LlamaProvider
    options: ChatRequestOptions(
        maxTokens: 2048,
        temperature: 0.7,
        systemPrompt: "You are a helpful assistant."
    )
)

// Send a user message (non-blocking, streams response)
session.send("Explain quantum entanglement simply.")

// Clear conversation history
session.clearHistory()

// Cancel an in-flight generation
session.cancel()
```

---

## Request Options

`ChatRequestOptions` is shared by all providers. Each provider uses the fields it supports and silently ignores the rest.

```swift
ChatRequestOptions(
    maxTokens:      2048,
    temperature:    0.7,
    topP:           0.95,
    stop:           ["<|eot_id|>"],
    tools:          [myToolDefinition],
    toolChoice:     .auto,
    systemPrompt:   "You are a helpful assistant.",
    // Anthropic only:
    thinkingBudget: 8000,
    // OpenAI reasoning models only:
    reasoningEffort: "high",
    // llama.cpp only (ignored by cloud providers):
    topK:           40,
    minP:           0.05,
    penaltyRepeat:  1.1,
    penaltyFreq:    0.0,
    penaltyPresent: 0.0
)
```

---

## Tool Use

All three providers support tool use through the same interface.

### Defining tools

```swift
import AIChatCore

let weatherTool = ChatRequestOptions.ToolDefinition(
    name: "get_current_weather",
    description: "Get the current weather in a city.",
    parameters: .object(
        properties: [
            "city":  .string(description: "City name"),
            "units": .enum(description: "Temperature units",
                           values: [.string("celsius"), .string("fahrenheit")])
        ],
        required: ["city"]
    )
)
```

### Streaming with tool calls

```swift
let options = ChatRequestOptions(
    tools: [weatherTool],
    toolChoice: .auto
)

for try await event in provider.stream(messages: history, model: model, options: options) {
    switch event {
    case .text(let delta):
        print(delta, terminator: "")

    case .toolCallComplete(let id, let name, let arguments):
        // Execute the tool call
        let result = executeMyTool(name: name, arguments: arguments)
        // Return result to the model
        session.submitToolResult(toolCallId: id, content: result)

    default:
        break
    }
}
```

`ChatSession` handles this loop automatically when using `ChatView`.

---

## Custom UI with ChatSession

`ChatSession` is a plain `ObservableObject` — you can drive any view from it without using `ChatView` at all. Import only `AIChatUI` (for `ChatSession`) and whichever provider you need; skip `ChatView` entirely.

```swift
import SwiftUI
import AIChatAnthropic
import AIChatUI

struct MyChatView: View {
    @StateObject private var session = ChatSession(
        provider: AnthropicProvider(apiKey: "sk-ant-…"),
        model: "claude-opus-4-8",
        options: ChatRequestOptions(systemPrompt: "You are a helpful assistant.")
    )
    @State private var input = ""

    var body: some View {
        VStack {
            ScrollView {
                ForEach(session.entries) { entry in
                    switch entry {
                    case .userMessage(let e):
                        Text(e.text)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                    case .aiMessage(let e):
                        Text(e.text)
                            .frame(maxWidth: .infinity, alignment: .leading)

                    case .reasoning(let e):
                        Text("Thinking… \(e.text)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    case .toolCall(let e):
                        Text("Tool: \(e.name) (\(e.status == .running ? "running" : "done"))")
                            .font(.caption)

                    case .activity(let e):
                        Text(e.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                TextField("Message", text: $input)
                Button("Send") {
                    session.send(input)
                    input = ""
                }
                .disabled(session.isGenerating || input.isEmpty)
            }
            .padding()
        }
    }
}
```

### What ChatSession gives you

| Property | Type | Description |
|---|---|---|
| `entries` | `[Entry]` | Ordered conversation entries — append-only during streaming |
| `isGenerating` | `Bool` | `true` while a stream is in flight |
| `error` | `Error?` | Set when a request fails |

### Entry types

| Case | Key fields | Notes |
|---|---|---|
| `.userMessage(UserEntry)` | `text` | The user's sent message |
| `.aiMessage(AIEntry)` | `text`, `isStreaming` | Text grows token-by-token while `isStreaming == true` |
| `.reasoning(ReasoningEntry)` | `text`, `duration`, `isThinking`, `isExpanded` | Anthropic extended thinking; `isThinking` becomes `false` when the block seals |
| `.toolCall(ToolCallEntry)` | `name`, `arguments`, `status`, `result` | Status is `.running` → `.succeeded`/`.failed` |
| `.activity(ActivityEntry)` | `text` | Transient state messages ("Thinking…", error banners) |

### Handling tool calls in a custom UI

When the model invokes a tool, a `.toolCall` entry appears with `status == .running`. Execute the tool yourself and return the result:

```swift
case .toolCall(let e) where e.status == .running:
    Button("Run \(e.name)") {
        let result = myToolExecutor.run(name: e.name, arguments: e.arguments)
        session.submitToolResult(toolCallId: e.id, content: result)
    }
```

`submitToolResult` appends the result to history and automatically continues the conversation.

---

## Streaming Protocol

Use providers directly without `ChatSession` when you need full control:

```swift
let stream = provider.stream(messages: history, model: "claude-opus-4-8", options: options)

for try await event in stream {
    switch event {
    case .text(let delta):              // incremental text
    case .reasoning(let delta):         // thinking text (Anthropic)
    case .thinkingBlockComplete(let thinking, let signature):  // sealed thinking block
    case .toolCallComplete(let id, let name, let arguments):   // tool invocation
    case .usage(let tokens):            // prompt/completion counts
    case .done:                         // stream finished
    }
}
```

---

## Anthropic Extended Thinking

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-…")
let session = ChatSession(
    provider: provider,
    model: "claude-opus-4-8",
    options: ChatRequestOptions(
        maxTokens: 16000,
        thinkingBudget: 8000   // enables extended thinking
    )
)
```

`ChatView` renders thinking blocks as collapsible tiles automatically.

---

## On-Device Inference — llama.cpp Details

`AIChatLlama` is built on a production-quality llama.cpp integration:

**Sampler chain** — uses the native `llama_sampler_chain_*` API for correct, composable sampling: repetition penalties → top-k → min-p → top-p → temperature → distribution. Fully configurable via `ChatRequestOptions`.

**KV cache reuse** — a single `LlamaContext` persists across conversation turns. The token prefix shared with the previous request is served directly from the KV cache; only new tokens are evaluated. For a 10-turn conversation this reduces inference work from O(n²) to O(n).

**Chat template** — tries the model's built-in Jinja template via `llama_chat_apply_template`. Falls back to a manual implementation for models whose templates exceed llama.cpp's parser (including Gemma 4).

**Tool use** — tool schemas are injected into the system message as JSON. Model output is scanned for `<tool_call>…</tool_call>` spans; each is parsed and emitted as a `.toolCallComplete` event before generation resumes.

**Metal GPU** — all layers offloaded to Metal by default (`nGpuLayers: 99`). Set to `-1` for CPU-only. GPU is automatically disabled on simulators.

**App Store safe** — no `dlopen()`, no runtime Metal shader compilation, no entitlements beyond `com.apple.security.network.client` for model downloads.

---

## Custom Provider

Conform to `ChatProvider` to add any backend:

```swift
import AIChatCore

struct MyProvider: ChatProvider {
    let id   = "my-provider"
    let name = "My Backend"

    func stream(
        messages: [ChatMessage],
        model: String,
        options: ChatRequestOptions
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // your streaming implementation
                continuation.yield(.text("Hello"))
                continuation.finish()
            }
        }
    }

    func complete(
        messages: [ChatMessage],
        model: String,
        options: ChatRequestOptions
    ) async throws -> ChatCompletionResult {
        // non-streaming implementation
    }
}
```

---

## Roadmap

- [ ] [**Multimodal image input**](#multimodal-image-input) — vision understanding for on-device inference via llama.cpp
- [ ] Streaming token usage counts for `AIChatLlama`
- [ ] Conversation persistence (Codable history export/import)
- [ ] Audio input support (Whisper integration)
- [ ] Model download manager with progress and resume

---

## Multimodal Image Input

> **Status:** Planned · Requires dependency restructure

### What it enables

Pass images alongside text to the `LlamaProvider` for on-device visual understanding — describing photos, reading diagrams, answering questions about screenshots. Cloud providers (OpenAI, Anthropic) already support images through `ChatMessage` content blocks; this work closes the gap for local inference.

### Why it isn't implemented yet

On-device image understanding requires the **mtmd** (multimodal) C++ API from llama.cpp. This API handles the vision encoder (CLIP), image tokenisation, and embedding injection. It is not part of the binary XCFramework that `AIChatLlama` currently depends on — it must be compiled from source alongside the framework.

This is a structural change to the package, not a Swift-level addition.

### Implementation plan

**Step 1 — Restructure the binary dependency**

Replace the current `mattt/llama.swift` SPM wrapper with a direct binary target pointing to the ggml-org XCFramework release. This gives explicit, pinned control over the exact llama.cpp version so the C++ bridge sources can be matched precisely.

```swift
// Package.swift (target state)
.binaryTarget(
    name: "LlamaFramework",
    url: "https://github.com/ggml-org/llama.cpp/releases/download/bXXXX/llama-bXXXX-xcframework.zip",
    checksum: "…"
)
```

**Step 2 — Add a C++ bridge target (`AIChatLlamaC`)**

Create a new SPM C++ target that vendors the mtmd source files from the matching llama.cpp version:

```
Sources/AIChatLlamaC/
├── include/
│   ├── AIChatLlamaC.h       ← public C API exposed to Swift
│   ├── llama.h              ← thin forwarding header → <llama/llama.h>
│   └── ggml.h               ← thin forwarding header → <llama/ggml.h>
├── mtmd.h                   ← vendored from llama.cpp tools/mtmd/
├── mtmd.cpp
├── mtmd-helper.h
├── mtmd-helper.cpp
├── clip.h                   ← vendored from llama.cpp tools/mtmd/
└── clip.cpp
```

`AIChatLlamaC.h` exposes a clean, stable C API to Swift — no C++ types cross the boundary:

```c
// Opaque handle to the multimodal context
typedef struct AIChatMultimodalCtx AIChatMultimodalCtx;

AIChatMultimodalCtx * aiChatMultimodal_create(
    const char * projectorPath,     // path to mmproj-*.gguf
    const void * llamaModel,        // OpaquePointer to llama_model
    bool useGPU
);

bool aiChatMultimodal_supportsVision(const AIChatMultimodalCtx * ctx);

// Encodes raw RGB bytes into the llama context at the given KV position.
// Returns the number of tokens consumed (to advance KV position).
int32_t aiChatMultimodal_encodeImage(
    AIChatMultimodalCtx * ctx,
    const void           * llamaCtx,
    const unsigned char  * rgbData,   // width × height × 3 bytes
    uint32_t               width,
    uint32_t               height,
    int32_t                kvPos,
    int32_t                seqId
);

void aiChatMultimodal_free(AIChatMultimodalCtx * ctx);
```

**Step 3 — Swift wrapper (`LlamaMultimodalContext.swift`)**

A Swift class wraps the C bridge, handling image loading via CoreGraphics (no additional dependencies):

```swift
final class LlamaMultimodalContext {
    // Loads a CGImage, scales it to the model's expected resolution,
    // converts to raw RGB, and calls aiChatMultimodal_encodeImage.
    func encode(image: CGImage, into context: LlamaContext) throws -> Int32
}
```

**Step 4 — `LlamaProvider` changes**

Add an optional `projectorPath` parameter. When set, a `LlamaMultimodalContext` is created alongside the text model. During prompt evaluation, image content blocks in the message history are encoded before their surrounding text tokens — exactly as the model expects.

```swift
let provider = LlamaProvider(
    modelPath:     "/path/to/model.gguf",
    projectorPath: "/path/to/mmproj.gguf",  // new
    contextSize:   8192,
    nGpuLayers:    99
)
```

Image content in messages flows through the existing `ChatMessage` content block model — no API changes on the consumer side.

**Step 5 — Model requirements**

Vision support requires two files:
- The main quantised model GGUF (e.g. `model-Q4_K_M.gguf`)
- A matching multimodal projector GGUF (e.g. `mmproj-model-f16.gguf`)

Both are available from the same quantisation sources that provide the text model. The projector is typically 300–600 MB depending on the vision encoder.

### Effort estimate

Medium — approximately one focused session. The Swift API surface is small; the bulk of the work is getting the C++ bridge to compile cleanly against the versioned binary, and validating the image encoding pipeline against a vision-capable model.
