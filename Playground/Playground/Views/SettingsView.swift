import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var bvm = vm

        Form {
            // ── OpenAI ───────────────────────────────────────────────────
            Section {
                LabeledContent("API Key") {
                    SecureField("sk-…", text: $bvm.openAIKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                LabeledContent("Models") {
                    Text("gpt-4o, gpt-4o-mini, o3-mini")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } header: {
                Label("OpenAI", systemImage: "bubble.left.and.bubble.right")
                    .foregroundStyle(.green)
            }

            // ── Anthropic ────────────────────────────────────────────────
            Section {
                LabeledContent("API Key") {
                    SecureField("sk-ant-…", text: $bvm.anthropicKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                LabeledContent("Models") {
                    Text("claude-opus-4-8, claude-sonnet-4-6")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } header: {
                Label("Anthropic", systemImage: "brain")
                    .foregroundStyle(.orange)
            }

            // ── llama.cpp server ─────────────────────────────────────────
            Section {
                LabeledContent("Endpoint") {
                    TextField("http://localhost:8080/v1/chat/completions",
                              text: $bvm.llamaServerURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                }
                LabeledContent("") {
                    Text("Start with: llama-server -m model.gguf --port 8080")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("llama.cpp Server", systemImage: "server.rack")
                    .foregroundStyle(.blue)
            } footer: {
                Text("No API key needed. Set stream_usage to false (already handled).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // ── llama.cpp local ───────────────────────────────────────────
            Section {
                LabeledContent("Model") {
                    VStack(alignment: .trailing, spacing: 4) {
                        if vm.localModelPath != nil {
                            Label("Gemma 4 E2B IT (downloaded)", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.callout)
                        } else {
                            Text("Not downloaded — use the Local demo to download.")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        Text(AppViewModel.localModelFileURL.path(percentEncoded: false))
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Label("llama.cpp Local (in-process)", systemImage: "cpu")
                    .foregroundStyle(.purple)
            }

            Divider()

            HStack {
                Spacer()
                Button("Save") {
                    vm.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.top, 4)
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
    }
}
