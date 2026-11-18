import Foundation

/// Constants of the iPhone <-> iPhone/iPad protocol.
enum PeerProtocol {
    static let version = 1
    static let minimumVersion = 1
    static let serviceType = "_swifttransfer._tcp"
    static let chunkSize = 256 * 1024
    /// Items sent ahead of their acknowledgement.
    static let ackWindow = 8
    /// One send plus up to two resends on a SHA-256 mismatch.
    static let maxAttempts = 3
}

struct HelloMessage: Codable, Sendable, Equatable {
    var protocolVersion: Int
    var minimumVersion: Int
    var deviceName: String
    var model: String
    var systemVersion: String
    var freeSpace: Int64?
    var sessionID: String

    /// Nil when compatible; otherwise which side must be updated.
    func incompatibility(with local: HelloMessage) -> PeerError? {
        if protocolVersion < local.minimumVersion {
            return .versionMismatch(peerNeedsUpdate: true)
        }
        if local.protocolVersion < minimumVersion {
            return .versionMismatch(peerNeedsUpdate: false)
        }
        return nil
    }
}

struct ManifestItem: Codable, Sendable, Equatable, Identifiable {
    var index: Int
    var id: String
    var category: DataCategory
    var path: String
    var size: Int64?
    var date: Date?

    var fileName: String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? "item\(index)" : name
    }
}

struct ManifestMessage: Codable, Sendable, Equatable {
    var sessionID: String
    var items: [ManifestItem]

    var totalBytes: Int64 {
        items.reduce(0) { $0 + ($1.size ?? 0) }
    }

    /// Item count and bytes per category in display order.
    var summaries: [(category: DataCategory, summary: CategorySummary)] {
        DataCategory.allCases.compactMap { category in
            let matching = items.filter { $0.category == category }
            guard !matching.isEmpty else { return nil }
            let bytes = matching.reduce(Int64(0)) { $0 + ($1.size ?? 0) }
            return (category, CategorySummary(itemCount: matching.count, byteCount: bytes))
        }
    }

    init(sessionID: String, items: [ManifestItem]) {
        self.sessionID = sessionID
        self.items = items
    }

    init(sessionID: String, entries: [TransferEntry]) {
        self.sessionID = sessionID
        self.items = entries.enumerated().map { index, entry in
            ManifestItem(
                index: index,
                id: entry.id,
                category: entry.category,
                path: entry.path,
                size: entry.byteCount,
                date: entry.modificationDate
            )
        }
    }
}

struct AcceptMessage: Codable, Sendable, Equatable {
    var policy: DuplicatePolicy
}

struct RejectMessage: Codable, Sendable, Equatable {
    var reason: String
}

struct ItemBeginMessage: Codable, Sendable, Equatable {
    var index: Int
    var offset: Int64
    var attempt: Int
}

struct ChunkHeader: Codable, Sendable, Equatable {
    var index: Int
}

struct ItemEndMessage: Codable, Sendable, Equatable {
    var index: Int
    var size: Int64
    var sha256: String
}

struct AckMessage: Codable, Sendable, Equatable {
    var index: Int
    var ok: Bool
    var reason: String?
}

struct EmptyMessage: Codable, Sendable, Equatable {}

struct PingMessage: Codable, Sendable, Equatable {
    var time: Double
}

struct ErrorMessage: Codable, Sendable, Equatable {
    enum Code: String, Codable, Sendable {
        case versionMismatch = "version_mismatch"
        case busy
        case readFailed = "read_failed"
        case noSpace = "no_space"
        case protocolError = "protocol"
        case unknownSession = "unknown_session"
    }

    var code: Code
    var message: String?
    var index: Int?
}

struct DoneMessage: Codable, Sendable, Equatable {
    var sent: Int
    var failed: [Int]
}

struct ImportReportMessage: Codable, Sendable, Equatable {
    var report: ImportReport
}

struct ResumeRequestMessage: Codable, Sendable, Equatable {
    var sessionID: String
}

struct ResumeStateMessage: Codable, Sendable, Equatable {
    var sessionID: String
    var acked: [Int]
    var failed: [Int]
    var partialIndex: Int?
    var partialOffset: Int64
}

/// Errors surfaced by the P2P sessions to the UI.
enum PeerError: Error, Equatable, Sendable {
    case localNetworkDenied
    /// TLS handshake failed: wrong code or a stale QR code.
    case authenticationFailed
    case versionMismatch(peerNeedsUpdate: Bool)
    case connectionFailed(String)
    case connectionLost
    case timeout
    case rejected(String)
    case cancelledByPeer
    case busy
    case insufficientSpace
    case protocolViolation(String)
    case tooManyAttempts
}
