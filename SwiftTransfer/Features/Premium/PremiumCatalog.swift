import PremiumKit
import StoreKit

@MainActor
enum PremiumCatalog {
    /// PremiumKit includes nonempty preview catalogs; only StoreKit-resolved products are purchasable.
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
            return ids == Set(products.map(\.id))
        } catch {
            return false
        }
    }
}
