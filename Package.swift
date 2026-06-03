// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AIChatKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AIChatCore",      targets: ["AIChatCore"]),
        .library(name: "AIChatOpenAI",    targets: ["AIChatOpenAI"]),
        .library(name: "AIChatAnthropic", targets: ["AIChatAnthropic"]),
        .library(name: "AIChatUI",        targets: ["AIChatUI"]),
        // Optional — only include when you need on-device llama.cpp inference
        .library(name: "AIChatLlama",     targets: ["AIChatLlama"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kevinhermawan/swift-json-schema.git",   .upToNextMajor(from: "2.0.1")),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git",    .upToNextMajor(from: "2.4.0")),
        .package(url: "https://github.com/JohnSundell/Splash.git",                exact: "0.16.0"),
        // llama.swift re-exports the llama.cpp XCFramework (~500 MB). Only pulled in
        // when AIChatLlama is added as a dependency in the consumer app.
        .package(url: "https://github.com/mattt/llama.swift",                     .upToNextMajor(from: "2.9469.0")),
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
