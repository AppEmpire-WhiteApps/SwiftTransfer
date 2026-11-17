// Generated placement table. Regenerate from a clean clone; do not edit.
internal enum PremiumKitTable37ead0b6fcf6b8d7 {
    private static let stream: [UInt8] = [195, 153, 69, 55, 249, 228, 181, 85, 173, 73, 29, 50, 80, 200, 114]
    private static let rows: [[UInt8]] = [[172, 247, 39, 88, 152, 150, 209, 60, 195, 46], [174, 248, 44, 89], [160, 246, 43, 68, 140, 137, 212, 55, 193, 44], [161, 248, 43, 89, 156, 150]]

    @inline(never)
    static func placement(_ index: Int) -> String {
        guard rows.indices.contains(index) else { return "" }
        let row = rows[index]
        let bytes = row.enumerated().map { offset, value in
            value ^ stream[offset % stream.count]
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
