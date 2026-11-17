import Foundation

enum PremiumRuntimeConfiguration {
    static var apiKey: String {
        let bytes = zip(PremiumApphudCredential.masked, PremiumApphudCredential.salt).map {
            $0 ^ $1
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    static var isEnabled: Bool {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-DisablePremium") { return false }
        #endif
        return !apiKey.isEmpty
    }

    static var forceFallback: Bool {
        #if DEBUG
            return ProcessInfo.processInfo.arguments.contains("-ForcePremiumFallback")
        #else
            return false
        #endif
    }
}
