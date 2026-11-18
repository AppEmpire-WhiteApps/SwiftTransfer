import CryptoKit
import Foundation
import Network
import Security

/// Content of the receiver's QR code: JSON encoded as base64url (TZ §8).
struct PeerQRPayload: Codable, Sendable, Equatable {
    /// Protocol version.
    var v: Int
    /// Bonjour service name of the receiver.
    var svc: String
    /// 32-byte pre-shared key, base64url.
    var psk: String
    /// Six-digit code (also shown on screen).
    var code: String
    /// Display name of the receiver.
    var name: String

    var pskData: Data? {
        TransferBase64URL.decode(psk).flatMap { $0.count == 32 ? $0 : nil }
    }

    /// base64url(JSON) string placed in the QR code.
    func encoded() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return TransferBase64URL.encode(try encoder.encode(self))
    }

    /// Parses a scanned string; returns nil for foreign QR codes.
    static func decode(_ string: String) -> PeerQRPayload? {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "swifttransfer:", options: [.caseInsensitive, .anchored]) {
            text = String(text[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        guard let data = TransferBase64URL.decode(text),
              let payload = try? JSONDecoder().decode(PeerQRPayload.self, from: data),
              payload.v >= 1,
              !payload.svc.isEmpty,
              payload.pskData != nil,
              payload.code.count == 6,
              payload.code.allSatisfy(\.isNumber)
        else { return nil }
        return payload
    }
}

/// A pre-shared key with the identity sent in the TLS handshake.
struct PeerPSK: Sendable, Equatable {
    static let qrIdentity = "swifttransfer-qr-v1"
    static let codeIdentity = "swifttransfer-code-v1"
    static let hkdfInfo = Data("swifttransfer-psk-v1".utf8)

    var identity: String
    var key: Data

    /// Random 32-byte key carried by the QR code.
    static func random() -> PeerPSK {
        PeerPSK(identity: qrIdentity, key: TransferSecrets.randomBytes(32))
    }

    /// Key derived from the 6-digit code with HKDF-SHA256 and the salt from the Bonjour TXT record.
    static func derived(code: String, salt: Data) -> PeerPSK {
        PeerPSK(identity: codeIdentity, key: deriveKey(code: code, salt: salt))
    }

    static func deriveKey(code: String, salt: Data) -> Data {
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(code.utf8)),
            salt: salt,
            info: hkdfInfo,
            outputByteCount: 32
        )
        return key.withUnsafeBytes { Data($0) }
    }
}

/// Network parameters for the encrypted P2P channel: TCP + TLS 1.2/1.3 with pre-shared keys.
enum PeerTLS {
    /// TLS_PSK_WITH_AES_128_GCM_SHA256 (RFC 5487).
    static let pskCipherSuite: UInt16 = 0x00A8

    static func parameters(psks: [PeerPSK]) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        for psk in psks {
            let key = psk.key.withUnsafeBytes { DispatchData(bytes: $0) }
            let identity = Data(psk.identity.utf8).withUnsafeBytes { DispatchData(bytes: $0) }
            sec_protocol_options_add_pre_shared_key(options, key as __DispatchData, identity as __DispatchData)
        }
        if let suite = tls_ciphersuite_t(rawValue: pskCipherSuite) {
            sec_protocol_options_append_tls_ciphersuite(options, suite)
        }
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 10
        tcp.keepaliveInterval = 5
        tcp.keepaliveCount = 4

        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.includePeerToPeer = true
        parameters.prohibitedInterfaceTypes = [.cellular]
        return parameters
    }

    /// True when an error means the TLS handshake failed (typically a wrong code).
    static func isAuthenticationError(_ error: Error) -> Bool {
        guard let networkError = error as? NWError else { return false }
        if case .tls = networkError {
            return true
        }
        return false
    }

    static func isPolicyDenied(_ error: Error) -> Bool {
        guard let networkError = error as? NWError else { return false }
        return WebReceiverServer.isPolicyDenied(networkError)
    }
}
