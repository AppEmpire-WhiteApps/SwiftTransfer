import Foundation

enum PremiumRuntimeConfiguration {
    static var apiKey: String {
        let bytes = zip(PremiumApphudCredential.masked, PremiumApphudCredential.salt).map {
            $0 ^ $1
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    static var isEnabled: Bool {
        !apiKey.isEmpty
    }

    static let forceFallback = false
}
