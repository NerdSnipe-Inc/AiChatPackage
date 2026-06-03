// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AIChatKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AIChatCore",             targets: ["AIChatCore"]),
        .library(name: "AIChatOpenAI",           targets: ["AIChatOpenAI"]),
        .library(name: "AIChatAnthropic",        targets: ["AIChatAnthropic"]),
        .library(name: "AIChatUI",               targets: ["AIChatUI"]),
        // On-device providers — add only what you need:
        .library(name: "AIChatLlama",            targets: ["AIChatLlama"]),            // llama.cpp GGUF (~500 MB binary)
        .library(name: "AIChatMLX",              targets: ["AIChatMLX"]),              // Apple MLX (Apple Silicon only)
        .library(name: "AIChatFoundationModels", targets: ["AIChatFoundationModels"]), // Apple Intelligence (macOS/iOS 26+)
    ],
    dependencies: [
        .package(url: "https://github.com/kevinhermawan/swift-json-schema.git",   .upToNextMajor(from: "2.0.1")),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git",    .upToNextMajor(from: "2.4.0")),
        .package(url: "https://github.com/JohnSundell/Splash.git",                exact: "0.16.0"),
        // llama.swift re-exports the llama.cpp XCFramework (~500 MB). Only pulled in
        // when AIChatLlama is added as a dependency in the consumer app.
        .package(url: "https://github.com/mattt/llama.swift",                     .upToNextMajor(from: "2.9469.0")),
        // mlx-swift-lm provides MLXLLM + MLXLMCommon for on-device MLX inference.
        // Only pulled in when AIChatMLX is added. Requires Apple Silicon.
        // 2.31.3 is used (not 3.x) because 3.x introduces a swift-syntax macro dependency
        // that conflicts on Swift 6.1+ toolchains. 2.31.3 has the same AsyncStream inference
        // API and no macro dependency.
        .package(url: "https://github.com/ml-explore/mlx-swift-lm",              .upToNextMinor(from: "2.31.3")),
    ],
    targets: [
        // ── Core ──────────────────────────────────────────────────────────────
        .target(
            name: "AIChatCore",
            dependencies: [
                .product(name: "JSONSchema", package: "swift-json-schema"),
            ],
            path: "Sources/AIChatCore"
        ),
        .testTarget(
            name: "AIChatCoreTests",
            dependencies: ["AIChatCore"],
            path: "Tests/AIChatCoreTests"
        ),

        // ── OpenAI-compatible (OpenAI, llama.cpp server, OpenRouter, …) ──────
        .target(
            name: "AIChatOpenAI",
            dependencies: ["AIChatCore"],
            path: "Sources/AIChatOpenAI"
        ),
        .testTarget(
            name: "AIChatOpenAITests",
            dependencies: ["AIChatOpenAI"],
            path: "Tests/AIChatOpenAITests"
        ),

        // ── Anthropic ─────────────────────────────────────────────────────────
        .target(
            name: "AIChatAnthropic",
            dependencies: ["AIChatCore"],
            path: "Sources/AIChatAnthropic"
        ),
        .testTarget(
            name: "AIChatAnthropicTests",
            dependencies: ["AIChatAnthropic"],
            path: "Tests/AIChatAnthropicTests"
        ),

        // ── llama.cpp in-process inference (optional, pulls large XCFramework) ─
        .target(
            name: "AIChatLlama",
            dependencies: [
                "AIChatCore",
                .product(name: "LlamaSwift", package: "llama.swift"),
            ],
            path: "Sources/AIChatLlama"
        ),
        .testTarget(
            name: "AIChatLlamaTests",
            dependencies: ["AIChatLlama"],
            path: "Tests/AIChatLlamaTests"
        ),

        // ── Apple MLX on-device inference (Apple Silicon only) ────────────────
        // Downloads models from Hugging Face Hub on first use.
        // Does not pull a binary XCFramework — MLX is a standard Swift package.
        .target(
            name: "AIChatMLX",
            dependencies: [
                "AIChatCore",
                .product(name: "MLXLLM",      package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "Sources/AIChatMLX"
        ),
        .testTarget(
            name: "AIChatMLXTests",
            dependencies: ["AIChatMLX"],
            path: "Tests/AIChatMLXTests"
        ),

        // ── Apple Foundation Models / Apple Intelligence (macOS/iOS 26+) ──────
        // No package dependency — FoundationModels is a system framework.
        // All public API is guarded with @available(macOS 26.0, iOS 26.0, *).
        .target(
            name: "AIChatFoundationModels",
            dependencies: ["AIChatCore"],
            path: "Sources/AIChatFoundationModels"
        ),
        .testTarget(
            name: "AIChatFoundationModelsTests",
            dependencies: ["AIChatFoundationModels"],
            path: "Tests/AIChatFoundationModelsTests"
        ),

        // ── SwiftUI Chat Interface ─────────────────────────────────────────────
        .target(
            name: "AIChatUI",
            dependencies: [
                "AIChatCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Splash",     package: "Splash"),
            ],
            path: "Sources/AIChatUI"
        ),
        .testTarget(
            name: "AIChatUITests",
            dependencies: ["AIChatUI"],
            path: "Tests/AIChatUITests"
        ),
    ]
)
