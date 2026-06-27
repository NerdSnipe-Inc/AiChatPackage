# AIChatKit Playground

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNerdSnipe-Inc%2FAiChatPackage%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/NerdSnipe-Inc/AiChatPackage)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNerdSnipe-Inc%2FAiChatPackage%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/NerdSnipe-Inc/AiChatPackage)

A macOS app that exercises every provider in the AIChatKit family side-by-side. Use it to explore capabilities, test your API keys, or as a reference implementation when integrating the packages into your own app.

> **Looking to add AI chat to your app?**  
> This repo is the Playground only. The installable packages are:
>
> | Package | Install via SPM |
> |---|---|
> | [AIChatKit](https://github.com/NerdSnipe-Inc/AIChatKit) | Core · OpenAI · Anthropic · Apple Intelligence · SwiftUI |
> | [AIChatKitLlama](https://github.com/NerdSnipe-Inc/AIChatKitLlama) | llama.cpp GGUF inference (~500 MB binary) |
> | [AIChatKitMLX](https://github.com/NerdSnipe-Inc/AIChatKitMLX) | Apple MLX inference (Apple Silicon only) |

---

## What the Playground covers

| Section | Demo | What it shows |
|---|---|---|
| **OpenAI** | Chat | Streaming text via `gpt-4o` |
| | Tool Use | Weather + book tools with auto-execution |
| | Vision | Image understanding (paste an image URL) |
| | Reasoning | Extended reasoning via `o3-mini` |
| **Anthropic** | Chat | Streaming text via `claude-sonnet-4-6` |
| | Extended Thinking | Collapsible thinking tiles via `claude-opus-4-8` |
| | Tool Use | Multi-turn tool call round-tripping |
| **llama.cpp (server)** | llama-server | OpenAI-compatible local HTTP server |
| **llama.cpp (local)** | Gemma 4 E2B | In-process GGUF inference, Metal GPU, ~3.5 GB download |
| **Apple MLX** | Gemma 4 E4B | On-device MLX inference, ~2.5 GB download |
| **Foundation Models** | Apple Intelligence | On-device via FoundationModels framework (macOS 26+) |

---

## Requirements

- macOS 14 or later (macOS 26 required for the Apple Intelligence demo)
- Xcode 16 or later
- Apple Silicon for the MLX demo
- API keys for OpenAI and/or Anthropic (entered in Settings once the app is running)

---

## Setup

All four repositories must be cloned as **siblings** in the same parent folder — the Playground references the packages via relative paths.

```bash
cd ~/path/to/your/projects

git clone https://github.com/NerdSnipe-Inc/AIChatKit.git
git clone https://github.com/NerdSnipe-Inc/AIChatKitLlama.git
git clone https://github.com/NerdSnipe-Inc/AIChatKitMLX.git
git clone https://github.com/NerdSnipe-Inc/AiChatPackage.git
```

Your folder should look like this:

```
your-projects/
├── AIChatKit/
├── AIChatKitLlama/
├── AIChatKitMLX/
└── AiChatPackage/          ← open this one in Xcode
    └── Playground/
        └── Playground.xcodeproj
```

Open `AiChatPackage/Playground/Playground.xcodeproj` in Xcode. On first open Xcode will resolve the three local packages automatically.

**Signing:** The Playground requires a signing team to enforce the App Sandbox. In Xcode, select the Playground target → Signing & Capabilities → set your team. This is a one-time local step and is not committed to the repo.

---

## Architecture notes

The Playground is built on the same public API any app would use — there is no private or internal access. If you want to understand how to integrate a provider, the Playground source is the reference:

- `AppViewModel.swift` — provider factories and demo catalogue
- `ChatDemoView.swift` — custom UI driven by `ChatSession.entries`
- `LlamaLocalView.swift` — model download + progress + in-process inference
- `MLXLocalView.swift` — HuggingFace Hub download + MLX load + chat
- `RootView.swift` — sidebar navigation and provider routing

All on-device demos (Llama and MLX) run entirely within the app sandbox. No data leaves the device during inference.

---

## License

MIT
