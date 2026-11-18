import Foundation
import SwiftData

/// An assistant conversation.
@Model
final class ChatThread {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread)
    var messages: [ChatMessage]

    init(title: String = "") {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.messages = []
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

/// One message in an assistant conversation.
@Model
final class ChatMessage {
    var id: UUID
    /// "user" or "assistant".
    var roleRaw: String
    var text: String
    /// `AssistantAction` raw values suggested with an assistant reply.
    var actionsRaw: [String]
    var createdAt: Date
    /// "sent", "failed".
    var statusRaw: String
    /// For failed user messages: an `LLMError` raw value or "stopped".
    var errorCode: String? = nil
    var thread: ChatThread?

    init(role: String, text: String, actions: [String] = [], status: String = "sent") {
        self.id = UUID()
        self.roleRaw = role
        self.text = text
        self.actionsRaw = actions
        self.createdAt = .now
        self.statusRaw = status
    }
}

extension ChatMessage {
    static let userRole = "user"
    static let assistantRole = "assistant"
    static let sentStatus = "sent"
    static let failedStatus = "failed"
    static let stoppedErrorCode = "stopped"

    var isUser: Bool {
        roleRaw == Self.userRole
    }

    var isFailed: Bool {
        statusRaw == Self.failedStatus
    }

    /// Known actions in their original order.
    var actions: [AssistantAction] {
        actionsRaw.compactMap(AssistantAction.init(rawValue:))
    }

    /// The request error for a failed message, nil when it was stopped by the user or not failed.
    var failure: LLMError? {
        errorCode.flatMap(LLMError.init(rawValue:))
    }
}

extension ChatThread {
    /// Deletes every conversation (Settings → "Clear chat history").
    static func deleteAll(in context: ModelContext) throws {
        let threads = try context.fetch(FetchDescriptor<ChatThread>())
        for thread in threads {
            context.delete(thread)
        }
        try context.save()
    }

    /// A short title from the first words of the first question.
    static func title(fromQuestion question: String, maxWords: Int = 6, maxLength: Int = 48) -> String {
        let words = question.split(whereSeparator: \.isWhitespace)
        var title = words.prefix(maxWords).joined(separator: " ")
        var truncated = words.count > maxWords
        if title.count > maxLength {
            title = String(title.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
            truncated = true
        }
        return truncated ? title + "…" : title
    }
}
