import Foundation

/// Incremental CRC-32 (IEEE 802.3, polynomial 0xEDB88320) as used by ZIP.
struct CRC32: Sendable {
    private(set) var value: UInt32 = 0
    private var state: UInt32 = 0xFFFF_FFFF

    init() {}

    mutating func update(_ data: Data) {
        data.withUnsafeBytes { buffer in
            update(buffer)
        }
    }

    mutating func update(_ buffer: UnsafeRawBufferPointer) {
        var crc = state
        CRC32.table.withUnsafeBufferPointer { table in
            for byte in buffer {
                let index = Int((crc ^ UInt32(byte)) & 0xFF)
                crc = table[index] ^ (crc >> 8)
            }
        }
        state = crc
        value = crc ^ 0xFFFF_FFFF
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc = CRC32()
        crc.update(data)
        return crc.value
    }

    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            if value & 1 == 1 {
                value = 0xEDB8_8320 ^ (value >> 1)
            } else {
                value >>= 1
            }
        }
        return value
    }
}
