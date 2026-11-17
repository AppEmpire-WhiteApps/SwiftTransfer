import CryptoKit
import Foundation

/// Fingerprints of the operator-supplied catalog, not prices or subscription eligibility.
enum PremiumCatalogManifest {
    private static let fingerprints: [String: String] = [
        "main": "420710843a68db6eb835d98d08e8acaad168c2ccc52c3d57871f683fbac831d0",
        "onboarding": "a7c722b1257718eb53ada51168e956f249db7d9db9d4762e693a6faeec6cb10c",
        "aiChat": "9053ceed72bfa421c3d08a8c0508e895af1645285f9c2e78a19cd2bba4113793",
    ]

    static func contains(_ productIDs: [String], placement: String) -> Bool {
        guard !productIDs.isEmpty else { return false }
        let data = Data(productIDs.sorted().joined(separator: "\n").utf8)
        let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return fingerprints[placement] == fingerprint
    }
}
