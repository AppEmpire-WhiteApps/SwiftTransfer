import Foundation

/// A parsed assistant reply: Markdown text plus up to three suggested actions.
struct AssistantReply: Equatable, Sendable {
    var text: String
    var actions: [AssistantAction]
}

/// Parses the model output (TZ §7.7).
///
/// Structured mode expects `{"text": "...", "actions": ["open_connection_check", ...]}`.
/// Anything that is not such an object falls back to the raw content as plain text without actions.
enum ReplyParser {
    static let maxActions = 3

    static func parse(_ content: String, structured: Bool = AppConfig.assistantStructuredReplies) -> AssistantReply {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard structured, let reply = parseJSON(trimmed) else {
            return AssistantReply(text: trimmed, actions: [])
        }
        return reply
    }

    private static func parseJSON(_ content: String) -> AssistantReply? {
        let json = stripCodeFence(content)
        guard json.hasPrefix("{"),
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = object["text"] as? String
        else {
            return nil
        }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawActions = object["actions"] as? [Any] ?? []
        var actions: [AssistantAction] = []
        for case let raw as String in rawActions {
            guard let action = AssistantAction(rawValue: raw), !actions.contains(action) else {
                continue
            }
            actions.append(action)
            if actions.count == maxActions {
                break
            }
        }
        return AssistantReply(text: trimmedText, actions: actions)
    }

    /// Removes a surrounding ```json … ``` fence some models add despite the schema.
    private static func stripCodeFence(_ content: String) -> String {
        guard content.hasPrefix("```"), content.hasSuffix("```"), content.count > 6 else {
            return content
        }
        var inner = content.dropFirst(3).dropLast(3)
        if let newline = inner.firstIndex(of: "\n") {
            let language = inner[inner.startIndex..<newline].trimmingCharacters(in: .whitespaces)
            if language.allSatisfy(\.isLetter) {
                inner = inner[inner.index(after: newline)...]
            }
        }
        return inner.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
