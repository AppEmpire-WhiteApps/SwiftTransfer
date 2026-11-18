import Foundation

/// The paid assistant needs an ordinary subscription AND an active aiChat product.
/// This policy is intentionally independent of the common photo/guide entitlement.
enum AssistantAccessPolicy {
    enum Gate {
        case main
        case assistant
    }

    static func requiredGate(
        sdkIsPremium: Bool,
        activeProductIDs: Set<String>,
        standardProductIDs: Set<String>,
        assistantProductIDs: Set<String>
    ) -> Gate? {
        // The SDK Boolean is also set by AI-only purchases. It is a compatibility
        // fallback for an ordinary entitlement ONLY when no active IDs are supplied.
        // Nonempty unknown IDs fail closed until their placements are loaded.
        let hasStandard =
            !activeProductIDs.isDisjoint(with: standardProductIDs)
            || (activeProductIDs.isEmpty && sdkIsPremium)
        guard hasStandard else { return .main }
        guard !activeProductIDs.isDisjoint(with: assistantProductIDs) else {
            return .assistant
        }
        return nil
    }
}
