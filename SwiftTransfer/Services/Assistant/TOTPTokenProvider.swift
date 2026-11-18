import CryptoKit
import Foundation

/// Creates a fresh LLMApps bearer token for every request (TZ §7.3).
///
/// ```
/// minutes = floor(unixTime / 60)
/// counter = UInt64(minutes) big-endian (8 bytes)
/// code    = base64url_nopad(HMAC-SHA256(key: base64url_decode(secret), data: counter))
/// token   = prefix + "_" + code
/// ```
actor TOTPTokenProvider {
    typealias KeyLoader = @Sendable () -> TOTPKey?
    typealias Clock = @Sendable () -> Date

    private let loadKey: KeyLoader
    private let now: Clock

    /// - Parameters:
    ///   - loadKey: Supplies the key on demand; it is not cached between tokens.
    ///   - now: Injectable clock for tests.
    init(
        loadKey: @escaping KeyLoader = { SecretStore.loadKey() },
        now: @escaping Clock = { Date() }
    ) {
        self.loadKey = loadKey
        self.now = now
    }

    /// Returns a token for the current minute.
    func token() throws -> String {
        guard let key = loadKey() else {
            throw LLMError.notConfigured
        }
        return try Self.token(for: key, at: now())
    }

    static func token(for key: TOTPKey, at date: Date) throws -> String {
        guard let secretData = key.secretData, !secretData.isEmpty else {
            throw LLMError.notConfigured
        }
        let minutes = UInt64(max(0, floor(date.timeIntervalSince1970 / 60)))
        let counter = withUnsafeBytes(of: minutes.bigEndian) { Data($0) }
        let mac = HMAC<SHA256>.authenticationCode(for: counter, using: SymmetricKey(data: secretData))
        return key.prefix + "_" + LLMBase64URL.encode(Data(mac))
    }
}
