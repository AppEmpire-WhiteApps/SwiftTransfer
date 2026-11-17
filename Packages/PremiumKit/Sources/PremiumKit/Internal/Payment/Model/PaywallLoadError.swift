import Foundation

/// Why a paywall could not be loaded from Apphud; logged before switching to the fallback.
enum PaywallLoadError: Error, CustomStringConvertible {
    case placementNotFound(String)
    case paywallNotAttached(String)
    case productNotLoaded(String, reason: String?)
    case timeout(seconds: Double)

    var description: String {
        switch self {
        case .placementNotFound(let placement):
            return "placement \"\(placement)\" not found in Apphud (missing in the dashboard or placements not fetched)"
        case .paywallNotAttached(let placement):
            return "placement \"\(placement)\" has no paywall attached"
        case .productNotLoaded(let productID, let reason):
            let suffix = reason.map { ": \($0)" } ?? ""
            return "product \"\(productID)\" was not loaded from StoreKit\(suffix)"
        case .timeout(let seconds):
            return "no response within \(Int(seconds)) s"
        }
    }
}
