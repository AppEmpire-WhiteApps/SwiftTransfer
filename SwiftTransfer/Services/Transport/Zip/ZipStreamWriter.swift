import Foundation

/// Destination of streamed bytes (an HTTP connection, a file, a test buffer).
typealias ZipByteSink = @Sendable (Data) async throws -> Void

enum ZipStreamError: Error, Equatable {
    case entryAlreadyOpen
    case noOpenEntry
    case finished
    case pathTooLong
}

/// Streaming ZIP writer: "store" method (no compression), data descriptors, CRC-32 computed
/// while streaming, UTF-8 names, DOS modification time and ZIP64 for big archives.
/// Nothing is buffered on disk; every byte goes straight to the sink.
actor ZipStreamWriter {
    struct Limits: Sendable {
        /// Sizes/offsets at or above this value use ZIP64 fields.
        var zip64Threshold: UInt64 = 0xFFFF_FFFF
        /// More entries than this need a ZIP64 end of central directory.
        var maxEntries: Int = 0xFFFF

        static let standard = Limits()
    }

    private struct CentralRecord {
        var nameBytes: Data
        var dosTime: UInt16
        var dosDate: UInt16
        var crc: UInt32
        var size: UInt64
        var localHeaderOffset: UInt64
        var usedZip64Descriptor: Bool
    }

    private struct OpenEntry {
        var record: CentralRecord
        var crc = CRC32()
        var written: UInt64 = 0
    }

    private let sink: ZipByteSink
    private let limits: Limits
    private var records: [CentralRecord] = []
    private var openEntry: OpenEntry?
    private var isFinished = false
    private(set) var bytesWritten: UInt64 = 0

    init(sink: @escaping ZipByteSink, limits: Limits = .standard) {
        self.sink = sink
        self.limits = limits
    }

    /// Starts a new entry. `expectedSize` decides whether a ZIP64 data descriptor is needed
    /// (unknown sizes always use ZIP64 so files above 4 GB stay valid).
    func beginEntry(path: String, modificationDate: Date?, expectedSize: Int64?) async throws {
        guard !isFinished else { throw ZipStreamError.finished }
        guard openEntry == nil else { throw ZipStreamError.entryAlreadyOpen }
        let nameBytes = Data(path.utf8)
        guard nameBytes.count <= 0xFFFF else { throw ZipStreamError.pathTooLong }
        let (time, date) = ZipFormat.dosDateTime(from: modificationDate ?? Date())
        let needsZip64: Bool
        if let expectedSize, expectedSize >= 0 {
            needsZip64 = UInt64(expectedSize) >= limits.zip64Threshold
        } else {
            needsZip64 = true
        }
        let record = CentralRecord(
            nameBytes: nameBytes,
            dosTime: time,
            dosDate: date,
            crc: 0,
            size: 0,
            localHeaderOffset: bytesWritten,
            usedZip64Descriptor: needsZip64
        )
        var header = Data()
        header.appendLE(UInt32(ZipFormat.localHeaderSignature))
        header.appendLE(UInt16(needsZip64 ? 45 : 20))
        header.appendLE(ZipFormat.generalPurposeFlags)
        header.appendLE(UInt16(0))
        header.appendLE(time)
        header.appendLE(date)
        header.appendLE(UInt32(0))
        if needsZip64 {
            header.appendLE(UInt32(0xFFFF_FFFF))
            header.appendLE(UInt32(0xFFFF_FFFF))
        } else {
            header.appendLE(UInt32(0))
            header.appendLE(UInt32(0))
        }
        header.appendLE(UInt16(nameBytes.count))
        header.appendLE(UInt16(needsZip64 ? 20 : 0))
        header.append(nameBytes)
        if needsZip64 {
            header.appendLE(UInt16(0x0001))
            header.appendLE(UInt16(16))
            header.appendLE(UInt64(0))
            header.appendLE(UInt64(0))
        }
        openEntry = OpenEntry(record: record)
        try await emit(header)
    }

    /// Appends bytes of the open entry.
    func write(_ data: Data) async throws {
        guard var entry = openEntry else { throw ZipStreamError.noOpenEntry }
        guard !data.isEmpty else { return }
        entry.crc.update(data)
        entry.written += UInt64(data.count)
        openEntry = entry
        try await emit(data)
    }

    /// Writes the data descriptor of the open entry.
    func endEntry() async throws {
        guard var entry = openEntry else { throw ZipStreamError.noOpenEntry }
        openEntry = nil
        entry.record.crc = entry.crc.value
        entry.record.size = entry.written
        if entry.written >= limits.zip64Threshold {
            entry.record.usedZip64Descriptor = true
        }
        var descriptor = Data()
        descriptor.appendLE(UInt32(ZipFormat.dataDescriptorSignature))
        descriptor.appendLE(entry.record.crc)
        if entry.record.usedZip64Descriptor {
            descriptor.appendLE(entry.written)
            descriptor.appendLE(entry.written)
        } else {
            descriptor.appendLE(UInt32(truncatingIfNeeded: entry.written))
            descriptor.appendLE(UInt32(truncatingIfNeeded: entry.written))
        }
        records.append(entry.record)
        try await emit(descriptor)
    }

    /// Convenience: writes a whole entry produced by `body`, which receives a chunk writer.
    func addEntry(
        path: String,
        modificationDate: Date?,
        expectedSize: Int64?,
        body: @Sendable (_ write: @escaping ZipByteSink) async throws -> Void
    ) async throws {
        try await beginEntry(path: path, modificationDate: modificationDate, expectedSize: expectedSize)
        try await body { [self] data in
            try await self.write(data)
        }
        try await endEntry()
    }

    /// Writes the central directory and the end records. The archive is complete afterwards.
    func finish() async throws {
        guard !isFinished else { throw ZipStreamError.finished }
        guard openEntry == nil else { throw ZipStreamError.entryAlreadyOpen }
        isFinished = true
        let directoryOffset = bytesWritten
        var directory = Data()
        for record in records {
            directory.append(centralHeader(for: record))
        }
        let directorySize = UInt64(directory.count)
        var trailer = Data()
        let needsZip64End = records.count > limits.maxEntries
            || directoryOffset >= limits.zip64Threshold
            || directorySize >= limits.zip64Threshold
            || records.contains { $0.usedZip64Descriptor || $0.size >= limits.zip64Threshold }
        if needsZip64End {
            let zip64EndOffset = directoryOffset + directorySize
            trailer.appendLE(UInt32(ZipFormat.zip64EndSignature))
            trailer.appendLE(UInt64(44))
            trailer.appendLE(ZipFormat.versionMadeBy)
            trailer.appendLE(UInt16(45))
            trailer.appendLE(UInt32(0))
            trailer.appendLE(UInt32(0))
            trailer.appendLE(UInt64(records.count))
            trailer.appendLE(UInt64(records.count))
            trailer.appendLE(directorySize)
            trailer.appendLE(directoryOffset)
            trailer.appendLE(UInt32(ZipFormat.zip64LocatorSignature))
            trailer.appendLE(UInt32(0))
            trailer.appendLE(zip64EndOffset)
            trailer.appendLE(UInt32(1))
        }
        let entryCountField = records.count >= 0xFFFF || records.count > limits.maxEntries
            ? UInt16(0xFFFF)
            : UInt16(records.count)
        trailer.appendLE(UInt32(ZipFormat.endOfCentralDirectorySignature))
        trailer.appendLE(UInt16(0))
        trailer.appendLE(UInt16(0))
        trailer.appendLE(entryCountField)
        trailer.appendLE(entryCountField)
        trailer.appendLE(clamp32(directorySize))
        trailer.appendLE(clamp32(directoryOffset))
        trailer.appendLE(UInt16(0))
        try await emit(directory + trailer)
    }

    private func centralHeader(for record: CentralRecord) -> Data {
        let sizeOverflow = record.usedZip64Descriptor || record.size >= limits.zip64Threshold
        let offsetOverflow = record.localHeaderOffset >= limits.zip64Threshold
        var extra = Data()
        if sizeOverflow || offsetOverflow {
            var fields = Data()
            if sizeOverflow {
                fields.appendLE(record.size)
                fields.appendLE(record.size)
            }
            if offsetOverflow {
                fields.appendLE(record.localHeaderOffset)
            }
            extra.appendLE(UInt16(0x0001))
            extra.appendLE(UInt16(fields.count))
            extra.append(fields)
        }
        var header = Data()
        header.appendLE(UInt32(ZipFormat.centralHeaderSignature))
        header.appendLE(ZipFormat.versionMadeBy)
        header.appendLE(UInt16(extra.isEmpty ? 20 : 45))
        header.appendLE(ZipFormat.generalPurposeFlags)
        header.appendLE(UInt16(0))
        header.appendLE(record.dosTime)
        header.appendLE(record.dosDate)
        header.appendLE(record.crc)
        let sizeField = sizeOverflow ? UInt32(0xFFFF_FFFF) : UInt32(record.size)
        header.appendLE(sizeField)
        header.appendLE(sizeField)
        header.appendLE(UInt16(record.nameBytes.count))
        header.appendLE(UInt16(extra.count))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(UInt16(0))
        header.appendLE(ZipFormat.externalAttributes)
        header.appendLE(offsetOverflow ? UInt32(0xFFFF_FFFF) : UInt32(record.localHeaderOffset))
        header.append(record.nameBytes)
        header.append(extra)
        return header
    }

    private func clamp32(_ value: UInt64) -> UInt32 {
        value >= limits.zip64Threshold ? 0xFFFF_FFFF : UInt32(value)
    }

    private func emit(_ data: Data) async throws {
        bytesWritten += UInt64(data.count)
        try await sink(data)
    }
}

/// ZIP format constants and helpers.
enum ZipFormat {
    static let localHeaderSignature: UInt32 = 0x0403_4B50
    static let dataDescriptorSignature: UInt32 = 0x0807_4B50
    static let centralHeaderSignature: UInt32 = 0x0201_4B50
    static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    static let zip64EndSignature: UInt32 = 0x0606_4B50
    static let zip64LocatorSignature: UInt32 = 0x0706_4B50
    /// Bit 3: sizes in data descriptor; bit 11: UTF-8 file names.
    static let generalPurposeFlags: UInt16 = 0x0808
    /// Unix host (3), spec version 4.5.
    static let versionMadeBy: UInt16 = (3 << 8) | 45
    /// Regular file with rw-r--r-- permissions.
    static let externalAttributes: UInt32 = UInt32(0o100644) << 16

    /// MS-DOS time and date in the current time zone; years before 1980 are clamped.
    static func dosDateTime(from date: Date, calendar: Calendar = .current) -> (time: UInt16, date: UInt16) {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = min(max((parts.year ?? 1980), 1980), 2107)
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let second = parts.second ?? 0
        let dosTime = UInt16((hour << 11) | (minute << 5) | (second / 2))
        let dosDate = UInt16(((year - 1980) << 9) | (month << 5) | day)
        return (dosTime, dosDate)
    }
}

fileprivate extension Data {
    mutating func appendLE(_ value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt64) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
