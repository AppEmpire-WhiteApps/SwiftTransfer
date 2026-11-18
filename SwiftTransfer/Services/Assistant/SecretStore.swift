import Foundation

/// Parsed LLMApps TOTP key `llm_totp_{prefix}_{secret}` (TZ §7.3).
///
/// Parsing uses fixed lengths because the base64url secret may itself contain `_`:
/// `prefix` is the first 20 characters (`llm_totp_` + 11), `secret` is everything after the 21st.
struct TOTPKey: Sendable, Equatable {
    static let prefixLength = 20
    static let scheme = "llm_totp_"

    let prefix: String
    let secret: String

    init?(rawKey: String) {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix(Self.scheme), key.count > Self.prefixLength + 1 else {
            return nil
        }
        let separatorIndex = key.index(key.startIndex, offsetBy: Self.prefixLength)
        guard key[separatorIndex] == "_" else {
            return nil
        }
        prefix = String(key.prefix(Self.prefixLength))
        secret = String(key.dropFirst(Self.prefixLength + 1))
    }

    /// The decoded HMAC key bytes, or nil when the secret is not valid base64url.
    var secretData: Data? {
        LLMBase64URL.decode(secret)
    }
}

/// Reads the XOR-masked key generated at build time (`LLMSecret`, see scripts/generate_llm_secret.sh).
/// The key is unmasked only in memory, on demand; it is never logged or persisted.
enum SecretStore {
    /// True when the build contains an LLMApps key.
    static var isConfigured: Bool {
        isConfigured(masked: BundledSecret.masked, salt: BundledSecret.salt)
    }

    static func isConfigured(masked: [UInt8], salt: [UInt8]) -> Bool {
        !masked.isEmpty && masked.count == salt.count && masked.count > TOTPKey.prefixLength + 1
    }

    /// Unmasks and parses the bundled key. Returns nil when no key is configured.
    static func loadKey() -> TOTPKey? {
        loadKey(masked: BundledSecret.masked, salt: BundledSecret.salt)
    }

    static func loadKey(masked: [UInt8], salt: [UInt8]) -> TOTPKey? {
        guard isConfigured(masked: masked, salt: salt) else {
            return nil
        }
        return TOTPKey(rawKey: unmask(masked: masked, salt: salt))
    }

    static func unmask(masked: [UInt8], salt: [UInt8]) -> String {
        let bytes = zip(masked, salt).map { $0 ^ $1 }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// The masked key bytes from the build-time generated `LLMSecret` enum.
///
/// `LLMSecret.generated.swift` is produced in DERIVED_FILE_DIR by the "Generate LLM Secret" phase
/// and compiled into the app target. Empty arrays mean no key is configured, so the assistant
/// shows its "available soon" state.
private enum BundledSecret {
    static let masked: [UInt8] = LLMSecret.masked
    static let salt: [UInt8] = LLMSecret.salt
}

/// base64url (RFC 4648 §5) helpers for the TOTP key and code.
enum LLMBase64URL {
    /// Decodes base64url, with or without padding.
    static func decode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }

    /// Encodes as base64url without padding.
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
