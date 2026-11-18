import CryptoKit
import Foundation

/// `manifest.json` written at the root of an external drive package.
struct BackupManifest: Codable, Equatable, Sendable {
    static let fileName = "manifest.json"
    static let formatIdentifier = "swifttransfer-package"

    struct Entry: Codable, Equatable, Sendable {
        var path: String
        var category: DataCategory
        var size: Int64
        var sha256: String
        var modified: Date?
    }

    var format = BackupManifest.formatIdentifier
    var version = 1
    var createdAt: Date
    var appVersion: String
    /// False while writing or when writing was interrupted.
    var complete: Bool
    var entries: [Entry]

    var totalBytes: Int64 {
        entries.reduce(0) { $0 + $1.size }
    }

    enum CodingKeys: String, CodingKey {
        case format
        case version
        case createdAt = "created_at"
        case appVersion = "app_version"
        case complete
        case entries
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> BackupManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupManifest.self, from: data)
    }
}

/// Incremental SHA-256 for streamed data.
struct StreamingSHA256 {
    private var hasher = SHA256()

    mutating func update(_ data: Data) {
        hasher.update(data: data)
    }

    func finalizeHex() -> String {
        Self.hex(hasher.finalize())
    }

    static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { byte in
            let text = String(byte, radix: 16)
            return byte < 16 ? "0" + text : text
        }.joined()
    }
}

enum FileHasher {
    static func sha256Hex(of data: Data) -> String {
        StreamingSHA256.hex(SHA256.hash(data: data))
    }

    /// Hashes a file in 1 MB chunks without loading it into memory.
    static func sha256Hex(ofFile url: URL, chunkSize: Int = 1 << 20) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = StreamingSHA256()
        while true {
            let chunk = try autoreleasepool { try handle.read(upToCount: chunkSize) }
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(chunk)
        }
        return hasher.finalizeHex()
    }
}
