import CryptoKit
import Foundation
import os

/// Framed message channel over an encrypted connection.
final class PeerChannel: Sendable {
    let io: ConnectionIO
    let generation: Int
    private let decoder = OSAllocatedUnfairLock(initialState: WireFrameDecoder())

    init(io: ConnectionIO, generation: Int) {
        self.io = io
        self.generation = generation
    }

    func send(_ frame: WireFrame) async throws {
        try await io.send(frame.encoded())
    }

    func send<Message: Encodable>(_ type: WireMessageType, _ message: Message, body: Data = Data()) async throws {
        try await send(try WireFrame(type: type, message: message, body: body))
    }

    /// Next frame; throws `ConnectionIOError.closed` at end of stream.
    func receive() async throws -> WireFrame {
        while true {
            if let frame = try decoder.withLock({ try $0.next() }) {
                return frame
            }
            guard let data = try await io.receive(maximum: 512 * 1024) else {
                throw ConnectionIOError.closed
            }
            decoder.withLock { $0.append(data) }
        }
    }

    func receive(timeout: TimeInterval) async throws -> WireFrame {
        let io = self.io
        return try await withTransportDeadline(seconds: timeout, onTimeout: { io.abort() }) { [self] in
            try await self.receive()
        }
    }

    func close() {
        io.close()
    }
}

enum TransferSHA256 {
    static func string(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    static func of(_ data: Data) -> String {
        string(SHA256.hash(data: data))
    }
}

enum IncomingItemError: Error, Equatable {
    case noOpenItem
    case unexpectedItem(Int)
    case offsetBeyondData(expected: Int64, actual: Int64)
}

/// Receiver-side writer of one item into the inbox with streaming SHA-256 verification.
/// Supports resuming a partially received file from an offset.
final class IncomingItemWriter {
    enum Verification: Equatable {
        case verified(URL)
        case mismatch(expected: String, actual: String)
    }

    let index: Int
    let fileURL: URL
    private var handle: FileHandle?
    private var hasher = SHA256()
    private(set) var bytesWritten: Int64 = 0

    /// Opens (or reopens for resume) the file for `index`. Existing bytes before `offset` are re-hashed.
    init(index: Int, fileURL: URL, offset: Int64) throws {
        self.index = index
        self.fileURL = fileURL
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if offset == 0 || !fileManager.fileExists(atPath: fileURL.path) {
            guard offset == 0 else {
                throw IncomingItemError.offsetBeyondData(expected: offset, actual: 0)
            }
            fileManager.createFile(
                atPath: fileURL.path,
                contents: nil,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            handle = try FileHandle(forWritingTo: fileURL)
            try handle?.truncate(atOffset: 0)
            return
        }
        let existing = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard existing >= offset else {
            throw IncomingItemError.offsetBeyondData(expected: offset, actual: existing)
        }
        let reader = try FileHandle(forReadingFrom: fileURL)
        var remaining = offset
        while remaining > 0 {
            let count = Int(min(remaining, 1024 * 1024))
            guard let data = try reader.read(upToCount: count), !data.isEmpty else { break }
            hasher.update(data: data)
            remaining -= Int64(data.count)
        }
        try reader.close()
        let writer = try FileHandle(forWritingTo: fileURL)
        try writer.truncate(atOffset: UInt64(offset))
        try writer.seekToEnd()
        handle = writer
        bytesWritten = offset
    }

    func append(_ data: Data) throws {
        guard let handle else { throw IncomingItemError.noOpenItem }
        try handle.write(contentsOf: data)
        hasher.update(data: data)
        bytesWritten += Int64(data.count)
    }

    /// Closes the file and compares the digest with the sender's.
    func finish(expectedSHA256: String) throws -> Verification {
        try handle?.close()
        handle = nil
        let actual = TransferSHA256.string(hasher.finalize())
        if actual.caseInsensitiveCompare(expectedSHA256) == .orderedSame {
            return .verified(fileURL)
        }
        try? FileManager.default.removeItem(at: fileURL)
        return .mismatch(expected: expectedSHA256, actual: actual)
    }

    /// Closes the file keeping the partial data (for resume after a disconnect).
    func suspend() {
        try? handle?.close()
        handle = nil
    }

    func discard() {
        try? handle?.close()
        handle = nil
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// Sender-side streaming of one item: re-chunks to 256 KB frames and hashes the whole file.
/// Bytes before `offset` (resume) are hashed but not sent.
enum OutgoingItemStreamer {
    struct Result: Sendable, Equatable {
        var size: Int64
        var sha256: String
    }

    private struct State {
        var hasher = SHA256()
        var position: Int64 = 0
    }

    static func stream(
        content: any TransferContent,
        entry: TransferEntry,
        index: Int,
        offset: Int64,
        sendChunk: @escaping @Sendable (Data) async throws -> Void,
        beforeChunk: @escaping @Sendable () async throws -> Void
    ) async throws -> Result {
        let state = OSAllocatedUnfairLock(uncheckedState: State())
        try await content.read(entry, offset: 0) { data in
            var cursor = data.startIndex
            while cursor < data.endIndex {
                let end = data.index(cursor, offsetBy: PeerProtocol.chunkSize, limitedBy: data.endIndex) ?? data.endIndex
                let piece = data[cursor..<end]
                cursor = end
                let start = state.withLock { current -> Int64 in
                    current.hasher.update(data: piece)
                    let start = current.position
                    current.position += Int64(piece.count)
                    return start
                }
                let pieceEnd = start + Int64(piece.count)
                guard pieceEnd > offset else { continue }
                let skip = max(0, offset - start)
                let toSend = Data(piece.dropFirst(Int(skip)))
                try await beforeChunk()
                try await sendChunk(toSend)
            }
        }
        return state.withLock { current in
            Result(size: current.position, sha256: TransferSHA256.string(current.hasher.finalize()))
        }
    }
}
