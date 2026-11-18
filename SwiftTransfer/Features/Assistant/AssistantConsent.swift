import Foundation

/// Explicit approval for sharing assistant data with LLMApps, independent of technical context settings.
struct AssistantConsent {
    private static let approvalKey = "assistant.llmAppsConsent.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isApproved: Bool {
        defaults.object(forKey: Self.approvalKey) as? Bool == true
    }

    /// Called only by the consent alert's Continue action. Never sends a request.
    func approve() {
        defaults.set(true, forKey: Self.approvalKey)
    }
}
