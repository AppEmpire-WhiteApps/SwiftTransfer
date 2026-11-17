import PremiumKit
import StoreKit

@MainActor
enum PremiumCatalog {
    /// Reject SDK previews while preserving its verified local fallback when StoreKit is unavailable.
    static func load(_ placement: PremiumPaywallID) async -> Bool {
        guard PremiumSetup.isConfigured else { return false }
        await Premium.shared.loadPaywall(placement)
        await Task.yield()
        guard let paywall = Premium.shared.paywall(for: placement), !paywall.products.isEmpty else {
            return false
        }
        do {
            let ids = Set(paywall.products.map(\.id))
            let products = try await Product.products(for: Array(ids))
            if ids == Set(products.map(\.id)) { return true }
        } catch {
            // The SDK's fallback owns offline prices; this layer only verifies catalog identity.
        }
        return PremiumCatalogManifest.contains(
            paywall.products.map(\.id), placement: placement.rawValue)
    }
}
