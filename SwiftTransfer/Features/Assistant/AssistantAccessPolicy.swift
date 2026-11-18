import Foundation

/// Uses the shared Premium status before checking the aiChat subscription.
enum AssistantAccessPolicy {
    enum Gate {
        case main
        case assistant
    }

    static func requiredGate(
        isPremium: Bool,
        hasAssistantSubscription: Bool
    ) -> Gate? {
        guard isPremium else { return .main }
        return hasAssistantSubscription ? nil : .assistant
    }
}
