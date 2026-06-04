// swift-tools-version: 5.10
// This file exists only to satisfy Xcode's package-discovery pass.
// The actual library products live in the three sibling packages:
//
//   ../AIChatKit       — AIChatCore, AIChatOpenAI, AIChatAnthropic, AIChatFoundationModels, AIChatUI
//   ../AIChatKitLlama  — AIChatLlama  (llama.cpp GGUF, ~500 MB binary)
//   ../AIChatKitMLX    — AIChatMLX    (Apple MLX, Apple Silicon only)
//
// The Playground Xcode project (Playground/Playground.xcodeproj) references those
// three packages directly via local path dependencies.

import PackageDescription

let package = Package(
    name: "AIChatPlayground",
    platforms: [.macOS(.v14), .iOS(.v17)]
)
