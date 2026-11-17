public struct PremiumPaywallID: Hashable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    
    public static let onboarding = PremiumPaywallID(PremiumKitTable37ead0b6fcf6b8d7.placement(0))
    public static let main = PremiumPaywallID(PremiumKitTable37ead0b6fcf6b8d7.placement(1))
    public static let consumable = PremiumPaywallID(PremiumKitTable37ead0b6fcf6b8d7.placement(2))
    public static let banner = PremiumPaywallID(PremiumKitTable37ead0b6fcf6b8d7.placement(3))
    
    public var isAvailablePaywall: Bool {
        self == .main || self == .onboarding
    }
}
