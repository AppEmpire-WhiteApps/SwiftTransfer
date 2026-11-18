import Foundation

/// Progress of a P2P transfer by bytes actually sent/received.
struct PeerProgressSnapshot: Sendable, Equatable {
    var bytesDone: Int64 = 0
    var bytesTotal: Int64 = 0
    var categoryBytesDone: [DataCategory: Int64] = [:]
    var categoryBytesTotal: [DataCategory: Int64] = [:]
    var categoryItemsDone: [DataCategory: Int] = [:]
    var categoryItemsTotal: [DataCategory: Int] = [:]
    var categoryFailures: [DataCategory: Int] = [:]
    var importDone = 0
    var importTotal = 0
    var isPaused = false
    var isReconnecting = false

    var fraction: Double {
        guard bytesTotal > 0 else { return 0 }
        return min(1, Double(bytesDone) / Double(bytesTotal))
    }

    /// Builds a snapshot from per-item byte counters.
    static func make(
        items: [ManifestItem],
        bytesPerItem: [Int: Int64],
        completed: Set<Int>,
        failed: Set<Int>
    ) -> PeerProgressSnapshot {
        var snapshot = PeerProgressSnapshot()
        for item in items {
            let done = bytesPerItem[item.index] ?? 0
            let total = item.size ?? (completed.contains(item.index) ? done : 0)
            let clamped = failed.contains(item.index) ? total : min(done, total)
            snapshot.bytesDone += clamped
            snapshot.bytesTotal += total
            snapshot.categoryBytesDone[item.category, default: 0] += clamped
            snapshot.categoryBytesTotal[item.category, default: 0] += total
            snapshot.categoryItemsTotal[item.category, default: 0] += 1
            if completed.contains(item.index) {
                snapshot.categoryItemsDone[item.category, default: 0] += 1
            }
            if failed.contains(item.index) {
                snapshot.categoryFailures[item.category, default: 0] += 1
            }
        }
        return snapshot
    }
}

/// Identity of this device sent in `hello`.
struct PeerDeviceInfo: Sendable, Equatable {
    var name: String
    var model: String
    var systemVersion: String

    func hello(sessionID: String, freeSpace: Int64?) -> HelloMessage {
        HelloMessage(
            protocolVersion: PeerProtocol.version,
            minimumVersion: PeerProtocol.minimumVersion,
            deviceName: name,
            model: model,
            systemVersion: systemVersion,
            freeSpace: freeSpace,
            sessionID: sessionID
        )
    }
}
