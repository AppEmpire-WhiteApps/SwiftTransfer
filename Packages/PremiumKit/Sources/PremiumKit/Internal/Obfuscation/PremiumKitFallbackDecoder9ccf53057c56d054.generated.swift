// Generated authenticated fallback decoder. Regenerate from a clean clone.
import CryptoKit
import Foundation

internal enum PremiumKitFallbackDecoder9ccf53057c56d054 {
    private static let headerBytes = 16
    private static let positions: [Int] = [31, 16, 30, 5, 23, 1, 4, 0, 28, 22, 27, 18, 24, 19, 14, 2, 13, 25, 17, 11, 21, 10, 3, 20, 6, 29, 15, 9, 7, 12, 8, 26]
    private static let orders: [[Int]] = [[12, 31, 4, 1, 11, 26, 9, 13, 8, 16, 27, 6, 20, 28, 18, 5, 2, 30, 14, 0, 25, 17, 24, 15, 21, 10, 22, 19, 3, 7, 23, 29], [7, 16, 30, 19, 4, 27, 29, 18, 28, 31, 14, 20, 10, 11, 8, 13, 25, 15, 24, 23, 26, 21, 12, 17, 0, 22, 3, 6, 9, 2, 5, 1], [17, 5, 26, 11, 6, 8, 1, 3, 27, 23, 13, 31, 18, 19, 9, 20, 22, 2, 30, 25, 0, 24, 14, 10, 28, 4, 7, 29, 15, 12, 21, 16], [24, 10, 18, 21, 17, 5, 7, 22, 26, 0, 28, 20, 11, 8, 13, 2, 30, 19, 27, 3, 31, 4, 25, 15, 23, 9, 14, 1, 6, 29, 12, 16], [17, 9, 2, 1, 8, 19, 31, 6, 29, 15, 7, 21, 12, 23, 27, 10, 11, 20, 26, 16, 28, 3, 22, 18, 25, 13, 5, 24, 4, 14, 0, 30], [31, 15, 26, 7, 23, 18, 3, 20, 16, 17, 24, 4, 14, 2, 8, 28, 27, 29, 22, 12, 13, 25, 30, 19, 0, 1, 9, 6, 10, 21, 11, 5], [6, 29, 15, 24, 25, 21, 22, 17, 7, 8, 30, 14, 12, 20, 27, 5, 11, 16, 18, 19, 4, 1, 23, 9, 3, 26, 28, 2, 0, 31, 13, 10], [22, 21, 25, 5, 27, 19, 23, 14, 0, 11, 6, 10, 12, 17, 30, 8, 4, 13, 3, 1, 9, 7, 31, 18, 20, 2, 28, 26, 15, 16, 24, 29]]

    static func decrypt(_ encryptedData: Data) -> Data? {
        guard encryptedData.count > headerBytes else { return nil }
        let payload = encryptedData.subdata(in: headerBytes..<encryptedData.count)
        let fragments: [[UInt8]] = [Segment35c5616e6a666e9b.nibbles, Segment0ff461f7ecfa4ec1.nibbles, Segment02b3e7569ab6f770.nibbles, Segmented4d146eace975a5.nibbles, Segment3606f4a145d4e5ed.nibbles, Segment54a86069953a8c7f.nibbles, Segment5daff80120eb2cce.nibbles, Segment3f2192ece1f514d1.nibbles]
        guard fragments.count == orders.count,
              fragments.allSatisfy({ $0.count == positions.count }) else { return nil }
        var permuted = [UInt8](repeating: 0, count: positions.count)
        for pair in stride(from: 0, to: fragments.count, by: 2) {
            var share = [UInt8](repeating: 0, count: positions.count)
            for slot in 0..<positions.count {
                share[orders[pair][slot]] = fragments[pair][slot] << 4
            }
            for slot in 0..<positions.count {
                share[orders[pair + 1][slot]] |= fragments[pair + 1][slot]
            }
            for index in share.indices {
                permuted[index] ^= share[index]
            }
        }
        var keyBytes = [UInt8](repeating: 0, count: positions.count)
        for (position, originalIndex) in positions.enumerated() {
            guard keyBytes.indices.contains(originalIndex) else { return nil }
            keyBytes[originalIndex] = permuted[position]
        }
        let key = SymmetricKey(data: Data(keyBytes))
        guard let sealedBox = try? AES.GCM.SealedBox(combined: payload) else { return nil }
        return try? AES.GCM.open(sealedBox, using: key)
    }
}
