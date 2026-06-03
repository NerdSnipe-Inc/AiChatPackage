import Foundation

/// Parses Server-Sent Events from a stream of text lines.
///
/// Conforms to the SSE spec (https://html.spec.whatwg.org/multipage/server-sent-events.html):
/// fields are separated by `:`, events are delimited by blank lines, `[DONE]` terminates the stream.
public struct SSEParser {

    public struct Event: Sendable {
        public let id: String?
        public let type: String?
        public let data: String
    }

    /// Parse events from any async sequence of lines (production: `URLSession.AsyncBytes.lines`).
    public static func events<Lines: AsyncSequence & Sendable>(
        from lines: Lines
    ) -> AsyncThrowingStream<Event, Error> where Lines.Element == String {
        AsyncThrowingStream { continuation in
            let task = Task {
                var currentId: String? = nil
                var currentType: String? = nil
                var dataBuffer: [String] = []

                do {
                    for try await line in lines {
                        try Task.checkCancellation()

                        if line.isEmpty {
                            // Blank line = dispatch event (if data present)
                            if !dataBuffer.isEmpty {
                                let data = dataBuffer.joined(separator: "\n")
                                guard data != "[DONE]" else {
                                    continuation.finish()
                                    return
                                }
                                continuation.yield(Event(id: currentId, type: currentType, data: data))
                            }
                            dataBuffer = []
                            currentType = nil
                            // Note: `id` persists across events per spec
                        } else if line.hasPrefix(":") {
                            // Comment — skip
                        } else {
                            let (field, value) = parseField(line)
                            switch field {
                            case "data":  dataBuffer.append(value)
                            case "event": currentType = value
                            case "id":    currentId = value.isEmpty ? nil : value
                            default:      break
                            }
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ChatError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    // MARK: - Private

    private static func parseField(_ line: String) -> (String, String) {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return (line, "")
        }
        let field = String(line[line.startIndex..<colonIndex])
        let rest  = line[line.index(after: colonIndex)...]
        let value = rest.hasPrefix(" ") ? String(rest.dropFirst()) : String(rest)
        return (field, value)
    }
}
