import SwiftUI
import AIChatCore
import AIChatUI

/// Wraps `ChatView` and, for tool demos, automatically executes the playground's
/// built-in tools so developers can see the full tool-call → result cycle live.
struct ChatDemoView: View {
    let demo: Demo
    @State var session: ChatSession
    @Environment(AppViewModel.self) private var vm
    /// Tracks tool call IDs we have already scheduled auto-execution for.
    /// Prevents duplicate Tasks when `onReceive` fires multiple times
    /// while the same tool call is still in `.running` state.
    @State private var scheduledToolIDs: Set<String> = []

    var body: some View {
        ChatView(session: session)
            .navigationTitle(demo.title)
            .navigationSubtitle(demo.subtitle)
            .toolbar { toolbarContent }
            .onReceive(session.$entries) { entries in
                autoExecuteTools(in: entries)
            }
            .onChange(of: session.isGenerating) { _, isGenerating in
                // Clear the dedup set when the user starts a new conversation turn
                // so that tool calls in a future turn can be executed again.
                if !isGenerating { scheduledToolIDs = [] }
            }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Clear") {
                session.clearHistory()
                vm.resetSession(for: demo)
            }
            .disabled(session.isGenerating)
        }
        ToolbarItem(placement: .secondaryAction) {
            infoLabel
        }
    }

    private var infoLabel: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(providerColor)
                .frame(width: 7, height: 7)
            Text(demo.provider.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var providerColor: Color {
        switch demo.provider {
        case .openai:      .green
        case .anthropic:   .orange
        case .llamaServer: .blue
        case .llamaLocal:  .purple
        }
    }

    // MARK: - Auto tool executor

    /// Watches session entries for running tool calls and executes the playground's
    /// built-in fake implementations, demonstrating the full tool → result cycle.
    ///
    /// `onReceive` fires on every entries mutation (tool call added, activity
    /// removed, etc.), so the same running tool call can appear in multiple
    /// callbacks. The `scheduledToolIDs` set ensures we only spawn one Task
    /// per tool call ID — preventing duplicate `submitToolResult` calls that
    /// would corrupt the conversation history.
    private func autoExecuteTools(in entries: [ChatSession.Entry]) {
        for entry in entries {
            guard case .toolCall(let tc) = entry, tc.status == .running else { continue }
            guard !scheduledToolIDs.contains(tc.id) else { continue }
            scheduledToolIDs.insert(tc.id)
            Task {
                // Brief delay so the "running" state is visible before the result arrives
                try? await Task.sleep(for: .milliseconds(700))
                let result = await executeTool(name: tc.name, arguments: tc.arguments)
                session.submitToolResult(toolCallId: tc.id, content: result)
            }
        }
    }

    private func executeTool(name: String, arguments: String) async -> String {
        let args = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8))) as? [String: Any] ?? [:]

        switch name {
        case "get_current_weather":
            let location = args["location"] as? String ?? "Unknown"
            let unit     = args["unit"]     as? String ?? "celsius"
            let temp     = Int.random(in: 14...28)
            let symbol   = unit == "celsius" ? "°C" : "°F"
            let conditions = ["Sunny", "Partly cloudy", "Overcast", "Light rain"].randomElement()!
            return """
            {
              "location": "\(location)",
              "temperature": \(temp),
              "unit": "\(unit)",
              "condition": "\(conditions)",
              "humidity": \(Int.random(in: 40...80))
            }
            """

        case "recommend_book":
            let ref   = args["reference"] as? String ?? "a classic"
            let genre = args["genre"]     as? String ?? "fiction"
            let books: [String: [String]] = [
                "fiction":     ["Brave New World by Aldous Huxley", "We by Yevgeny Zamyatin", "Fahrenheit 451 by Ray Bradbury"],
                "non-fiction": ["Thinking, Fast and Slow by Daniel Kahneman", "Sapiens by Yuval Noah Harari", "The Power of Habit by Charles Duhigg"],
            ]
            let pick = books[genre]?.randomElement() ?? "The Hitchhiker's Guide to the Galaxy"
            return """
            {
              "recommendation": "\(pick)",
              "reason": "Similar themes and style to \(ref).",
              "genre": "\(genre)"
            }
            """

        default:
            return "{\"error\": \"Tool '\(name)' not implemented in this playground.\"}"
        }
    }
}
