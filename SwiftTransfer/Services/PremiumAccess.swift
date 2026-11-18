import Combine
import Foundation
import Observation
import PremiumKit

/// Paid assistant access checks the shared Premium status and then the aiChat subscription.
enum PremiumFeature {
    case assistant
    case photos
    case guides
}

enum PremiumRoute: String, Identifiable {
    case main
    case assistant

    var id: String { rawValue }

    var paywallID: PremiumPaywallID {
        switch self {
        case .main: .main
        case .assistant: PremiumPaywallID("aiChat")
        }
    }
}

@MainActor
@Observable
final class PremiumAccess {
    var isPremium: Bool {
        access(keyPath: \.isPremium)
        if entitlementSource.isPremium { return true }

        let paywalls = entitlementSource.paywalls
        let placements: [PremiumPaywallID] = [.main, .onboarding, PremiumRoute.assistant.paywallID]
        let accessIDs = Set(placements.flatMap { paywalls[$0]?.products ?? [] }.map(\.id))
        let consumableIDs = Set(
            paywalls.values.flatMap(\.products).filter { $0.consumable != nil }.map(\.id)
        )
        return !entitlementSource.activeProductIds.isDisjoint(
            with: accessIDs.subtracting(consumableIDs))
    }

    /// Uses the same Premium status and aiChat product membership as the Settings banner.
    var assistantPaywallRoute: PremiumRoute? {
        access(keyPath: \.isPremium)
        let assistantIDs = Set(
            (entitlementSource.paywalls[PremiumRoute.assistant.paywallID]?.products ?? []).map(\.id)
        )
        switch AssistantAccessPolicy.requiredGate(
            isPremium: isPremium,
            hasAssistantSubscription: !entitlementSource.activeProductIds.isDisjoint(
                with: assistantIDs)
        ) {
        case .main: return .main
        case .assistant: return .assistant
        case nil: return nil
        }
    }

    var paywallRoute: PremiumRoute?
    @ObservationIgnored private let entitlementSource: any PremiumEntitlementSource
    @ObservationIgnored private var subscription: AnyCancellable?

    convenience init(entitlement: AnyPublisher<Bool, Never>? = nil) {
        if let entitlement {
            self.init(source: PublisherPremiumEntitlement(entitlement))
        } else {
            self.init(source: Premium.shared)
        }
    }

    init(source: any PremiumEntitlementSource) {
        entitlementSource = source
        subscription = source.premiumChanges.sink { [weak self] _ in
            // PremiumKit publishes in willSet. Invalidate Observation now; consumers read
            // the SDK's committed value on their next render, not a second stored Boolean.
            self?.withMutation(keyPath: \.isPremium) {}
        }
    }

    @discardableResult
    func authorize(_ feature: PremiumFeature) -> Bool {
        if feature == .assistant {
            if let route = assistantPaywallRoute {
                paywallRoute = route
                return false
            }
            return true
        }
        guard isPremium else {
            paywallRoute = .main
            return false
        }
        return true
    }

    @discardableResult
    func authorizeGuide(_ guide: GuideID) -> Bool {
        !guide.requiresPremium || authorize(.guides)
    }

    func canAccessGuide(_ guide: GuideID) -> Bool {
        !guide.requiresPremium || isPremium
    }

    @discardableResult
    func authorizeFAQItem(_ item: GuideFAQItem) -> Bool {
        !item.requiresPremium || authorize(.guides)
    }

    func canAccessFAQItem(_ item: GuideFAQItem) -> Bool {
        !item.requiresPremium || isPremium
    }

    @discardableResult
    func authorizePhotos(_ selection: TransferSelection, preparedEntries: [TransferEntry]? = nil)
        -> Bool
    {
        // A retry's prepared subset, rather than the original selection, defines what will be sent.
        let containsPhotos =
            preparedEntries.map { PhotoTransferPolicy.containsPhotos(in: $0) }
            ?? PhotoTransferPolicy.containsPhotos(in: selection)
        return !containsPhotos || authorize(.photos)
    }

    @discardableResult
    func authorizePhotoItems(_ items: [ReceivedItem]) -> Bool {
        !PhotoTransferPolicy.containsPhotos(in: items) || authorize(.photos)
    }
}

/// Read-only SDK authority for the common entitlement and placement-specific assistant policy.
/// Token/consumable products never confer placement access.
@MainActor
protocol PremiumEntitlementSource: AnyObject {
    var isPremium: Bool { get }
    var activeProductIds: Set<String> { get }
    var paywalls: [PremiumPaywallID: PremiumPaywall] { get }
    var premiumChanges: AnyPublisher<Void, Never> { get }
}

extension Premium: PremiumEntitlementSource {
    var premiumChanges: AnyPublisher<Void, Never> {
        Publishers.Merge3(
            $isPremium.map { _ in () },
            $activeProductIds.map { _ in () },
            $paywalls.map { _ in () }
        ).eraseToAnyPublisher()
    }
}

/// Compatibility adapter for existing tests/callers injecting a Boolean publisher.
/// Production uses Premium.shared directly, without a second stored entitlement.
@MainActor
private final class PublisherPremiumEntitlement: PremiumEntitlementSource {
    private let value = CurrentValueSubject<Bool, Never>(false)
    private var subscription: AnyCancellable?
    var isPremium: Bool { value.value }
    var activeProductIds: Set<String> { [] }
    var paywalls: [PremiumPaywallID: PremiumPaywall] { [:] }
    var premiumChanges: AnyPublisher<Void, Never> {
        value.map { _ in () }.eraseToAnyPublisher()
    }

    init(_ publisher: AnyPublisher<Bool, Never>) {
        subscription = publisher.sink { [value] in value.send($0) }
    }
}

/// Configure the existing placements with Apphud and the bundled fallback before release.
@MainActor
enum PremiumSetup {
    static var apiKey: String { PremiumRuntimeConfiguration.apiKey }
    static let fallbackFileName = "pk_8f88ae6dbee6919e13941422"
    static var isConfigured: Bool { PremiumRuntimeConfiguration.isEnabled }

    static func configureIfReady() {
        guard isConfigured else { return }
        Premium.shared.configure(
            PremiumConfiguration(
                apiKey: apiKey,
                supportedLanguages: [.en, .ru, .de, .fr, .es, .it, .cs, .ko, .pl, .pt, .tr, .uk],
                defaultLanguage: .en,
                forceFallback: PremiumRuntimeConfiguration.forceFallback,
                fallbackFileName: fallbackFileName,
                isLoggingEnabled: false
            )
        )
    }
}
