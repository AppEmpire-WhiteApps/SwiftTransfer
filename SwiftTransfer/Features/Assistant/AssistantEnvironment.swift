import SwiftUI

private struct AssistantClientKey: EnvironmentKey {
    static let defaultValue: (any LLMClienting)? = AssistantBackend.defaultClient
}

extension EnvironmentValues {
    /// The LLM client for the assistant; nil when no key is configured ("available soon" state).
    /// Previews and tests inject `MockLLMClient()`.
    var assistantClient: (any LLMClienting)? {
        get { self[AssistantClientKey.self] }
        set { self[AssistantClientKey.self] = newValue }
    }
}

/// One opened conversation. A new `id` recreates the chat screen; `threadID` is filled in
/// when the first question creates the thread, without recreating the screen.
struct AssistantChatSession: Identifiable, Equatable {
    let id = UUID()
    var threadID: UUID?
}
