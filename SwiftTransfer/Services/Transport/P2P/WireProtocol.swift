import Foundation

/// Message types of the P2P protocol (TZ §8). The raw value is the first byte of every frame.
enum WireMessageType: UInt8, Sendable, CaseIterable {
    case hello = 1
    case manifest = 2
    case accept = 3
    case reject = 4
    case itemBegin = 5
    case chunk = 6
    case itemEnd = 7
    case ack = 8
    case pause = 9
    case resume = 10
    case cancel = 11
    case ping = 12
    case pong = 13
    case error = 14
    case done = 15
    case importReport = 16
    case resumeRequest = 17
    case resumeState = 18
}

enum WireProtocolError: Error, Equatable {
    case unknownMessageType(UInt8)
    case headerTooLarge(UInt32)
    case bodyTooLarge(UInt64)
    case invalidHeader(String)
}

/// One frame: `[1 byte type][4 bytes header length][JSON header][8 bytes body length][body]`,
/// lengths in network byte order.
struct WireFrame: Sendable, Equatable {
    var type: WireMessageType
    var header: Data
    var body: Data

    init(type: WireMessageType, header: Data = Data("{}".utf8), body: Data = Data()) {
        self.type = type
        self.header = header
        self.body = body
    }

    init<Header: Encodable>(type: WireMessageType, message: Header, body: Data = Data()) throws {
        self.init(type: type, header: try WireCodec.encoder.encode(message), body: body)
    }

    func decode<Header: Decodable>(_ type: Header.Type) throws -> Header {
        do {
            return try WireCodec.decoder.decode(Header.self, from: header)
        } catch {
            throw WireProtocolError.invalidHeader(String(describing: error))
        }
    }

    func encoded() -> Data {
        WireCodec.encode(self)
    }
}

enum WireCodec {
    static let prefixLength = 1 + 4
    /// Manifests of large libraries can be several megabytes.
    static let maxHeaderLength: UInt32 = 64 * 1024 * 1024
    static let maxBodyLength: UInt64 = 16 * 1024 * 1024

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    static func encode(_ frame: WireFrame) -> Data {
        var data = Data(capacity: 13 + frame.header.count + frame.body.count)
        data.append(frame.type.rawValue)
        appendBigEndian(UInt32(frame.header.count), to: &data)
        data.append(frame.header)
        appendBigEndian(UInt64(frame.body.count), to: &data)
        data.append(frame.body)
        return data
    }

    static func appendBigEndian(_ value: UInt32, to data: inout Data) {
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }

    static func appendBigEndian(_ value: UInt64, to data: inout Data) {
        withUnsafeBytes(of: value.bigEndian) { data.append(contentsOf: $0) }
    }
}

/// Incremental frame decoder: handles partial buffers and several frames per buffer.
struct WireFrameDecoder: Sendable {
    private var buffer = Data()
    private var readOffset = 0

    init() {}

    /// Bytes waiting for a complete frame.
    var bufferedByteCount: Int { buffer.count - readOffset }

    mutating func append(_ data: Data) {
        if readOffset > 0, readOffset >= buffer.count / 2 {
            buffer = Data(buffer.dropFirst(readOffset))
            readOffset = 0
        }
        buffer.append(data)
    }

    /// Returns the next complete frame or nil when more bytes are needed.
    mutating func next() throws -> WireFrame? {
        let available = buffer.count - readOffset
        guard available >= WireCodec.prefixLength else { return nil }
        let base = buffer.startIndex + readOffset
        guard let type = WireMessageType(rawValue: buffer[base]) else {
            throw WireProtocolError.unknownMessageType(buffer[base])
        }
        let headerLength = readUInt32(at: base + 1)
        guard headerLength <= WireCodec.maxHeaderLength else {
            throw WireProtocolError.headerTooLarge(headerLength)
        }
        let bodyLengthOffset = WireCodec.prefixLength + Int(headerLength)
        guard available >= bodyLengthOffset + 8 else { return nil }
        let bodyLength = readUInt64(at: base + bodyLengthOffset)
        guard bodyLength <= WireCodec.maxBodyLength else {
            throw WireProtocolError.bodyTooLarge(bodyLength)
        }
        let total = bodyLengthOffset + 8 + Int(bodyLength)
        guard available >= total else { return nil }
        let headerStart = base + WireCodec.prefixLength
        let header = Data(buffer[headerStart..<(headerStart + Int(headerLength))])
        let bodyStart = base + bodyLengthOffset + 8
        let body = Data(buffer[bodyStart..<(bodyStart + Int(bodyLength))])
        readOffset += total
        if readOffset == buffer.count {
            buffer = Data()
            readOffset = 0
        }
        return WireFrame(type: type, header: header, body: body)
    }

    private func readUInt32(at index: Int) -> UInt32 {
        var value: UInt32 = 0
        for offset in 0..<4 {
            value = (value << 8) | UInt32(buffer[index + offset])
        }
        return value
    }

    private func readUInt64(at index: Int) -> UInt64 {
        var value: UInt64 = 0
        for offset in 0..<8 {
            value = (value << 8) | UInt64(buffer[index + offset])
        }
        return value
    }
}
