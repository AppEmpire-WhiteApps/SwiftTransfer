import Foundation

/// Chooses the LLM client for the running app.
enum AssistantBackend {
    /// The client used by the app, or nil when no key is configured (the assistant shows "available soon").
    static let defaultClient: (any LLMClienting)? = makeClient()

    static func makeClient() -> (any LLMClienting)? {
        guard SecretStore.isConfigured else {
            return nil
        }
        return LLMClient()
    }
}
