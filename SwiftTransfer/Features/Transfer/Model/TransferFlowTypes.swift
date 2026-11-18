import Foundation

/// Screens of the full-screen transfer flow.
enum TransferRoute: Hashable {
    /// S3 "Where to?"
    case chooseTarget
    /// S3 "From where?"
    case chooseOrigin
    /// S5, owned by the data layer.
    case selectData(TransferTarget)
    /// S4a: QR + link + code for the Android browser (download or upload mode).
    case webConnect
    /// S4b: scanner, nearby devices, code entry.
    case peerScan
    /// S4c: QR + code on the receiving iPhone/iPad.
    case peerWait
    /// S4d: incoming transfer confirmation.
    case incoming
    /// S6
    case progress
    /// S7
    case result
    /// Connection error, local network denied, version mismatch…
    case failure

    var step: StepIndicator.Step {
        switch self {
        case .chooseTarget, .chooseOrigin: .launch
        case .webConnect, .peerScan, .peerWait, .incoming, .failure: .connect
        case .selectData: .select
        case .progress, .result: .transfer
        }
    }

    var showsAssistantButton: Bool {
        switch self {
        case .webConnect, .peerScan, .peerWait, .selectData, .progress: true
        case .chooseTarget, .chooseOrigin, .incoming, .result, .failure: false
        }
    }
}

/// Why a transfer could not start or continue.
enum TransferFailure: Equatable, Sendable {
    case connectionTimeout
    case localNetworkDenied
    case authenticationFailed
    case versionMismatch(peerNeedsUpdate: Bool)
    case connectionLost
    case rejected
    case cancelledByPeer
    case busy
    case insufficientSpace
    case nothingToSend
    case generic(String)

    init(_ error: PeerError) {
        switch error {
        case .localNetworkDenied: self = .localNetworkDenied
        case .authenticationFailed: self = .authenticationFailed
        case .versionMismatch(let peerNeedsUpdate): self = .versionMismatch(peerNeedsUpdate: peerNeedsUpdate)
        case .connectionFailed, .connectionLost, .protocolViolation: self = .connectionLost
        case .timeout, .tooManyAttempts: self = .connectionTimeout
        case .rejected: self = .rejected
        case .cancelledByPeer: self = .cancelledByPeer
        case .busy: self = .busy
        case .insufficientSpace: self = .insufficientSpace
        }
    }

    /// Technical code for the assistant context (no personal data).
    var code: String {
        switch self {
        case .connectionTimeout: "connection_timeout"
        case .localNetworkDenied: "local_network_denied"
        case .authenticationFailed: "authentication_failed"
        case .versionMismatch: "version_mismatch"
        case .connectionLost: "connection_lost"
        case .rejected: "rejected"
        case .cancelledByPeer: "cancelled_by_peer"
        case .busy: "busy"
        case .insufficientSpace: "insufficient_space"
        case .nothingToSend: "nothing_to_send"
        case .generic: "error"
        }
    }

    var title: String {
        switch self {
        case .connectionTimeout, .connectionLost, .busy: String(localized: "Couldn't connect")
        case .localNetworkDenied: String(localized: "Allow local network access")
        case .authenticationFailed: String(localized: "The code doesn't match")
        case .versionMismatch: String(localized: "Update the app")
        case .rejected: String(localized: "The transfer was declined")
        case .cancelledByPeer: String(localized: "The other device cancelled the transfer")
        case .insufficientSpace: String(localized: "Not enough free space")
        case .nothingToSend: String(localized: "Nothing to send")
        case .generic: String(localized: "Something went wrong")
        }
    }

    var message: String {
        switch self {
        case .connectionTimeout:
            String(localized: "The devices didn't find each other within 60 seconds. Make sure both are on the same Wi-Fi network (or use Personal Hotspot), keep them close and turn off VPN.")
        case .connectionLost:
            String(localized: "The connection was interrupted and couldn't be restored. Keep the devices close and on the same Wi-Fi network, then try again.")
        case .busy:
            String(localized: "The other device is already busy with another transfer.")
        case .localNetworkDenied:
            String(localized: "The app needs access to the local network to find and connect to nearby devices. Turn on Local Network for this app in Settings.")
        case .authenticationFailed:
            String(localized: "Check the 6-digit code on the other device or scan its QR code again.")
        case .versionMismatch(let peerNeedsUpdate):
            peerNeedsUpdate
                ? String(localized: "The other device uses an older version of the app. Update the app on both devices from the App Store.")
                : String(localized: "The other device uses a newer version of the app. Update the app on this device from the App Store.")
        case .rejected:
            String(localized: "The receiving device declined the transfer. Nothing was sent.")
        case .cancelledByPeer:
            String(localized: "The transfer was stopped on the other device.")
        case .insufficientSpace:
            String(localized: "Free up some space on the receiving device and try again.")
        case .nothingToSend:
            String(localized: "The selected categories contain no data to send.")
        case .generic(let detail):
            detail
        }
    }
}

/// Progress of one category on S6.
struct CategoryProgress: Identifiable, Equatable {
    var category: DataCategory
    var itemsDone = 0
    var itemsTotal = 0
    var bytesDone: Int64 = 0
    var bytesTotal: Int64 = 0
    var failures = 0

    var id: DataCategory { category }

    var isComplete: Bool {
        itemsTotal > 0 && itemsDone + failures >= itemsTotal
    }

    var status: CheckStatus {
        if isComplete {
            return failures > 0 ? .warning : .ok
        }
        return bytesDone > 0 || itemsDone > 0 ? .running : .pending
    }
}

/// Everything S6 shows.
struct TransferProgressState: Equatable {
    var bytesDone: Int64 = 0
    var bytesTotal: Int64 = 0
    var categories: [CategoryProgress] = []
    var bytesPerSecond: Double?
    var isPaused = false
    var isReconnecting = false
    var isImporting = false
    var importDone = 0
    var importTotal = 0
    /// Web download: every item was delivered at least once.
    var allDelivered = false
    /// Web upload: files received so far.
    var receivedFiles = 0

    var fraction: Double {
        if isImporting, importTotal > 0 {
            return min(1, Double(importDone) / Double(importTotal))
        }
        guard bytesTotal > 0 else { return 0 }
        return min(1, Double(bytesDone) / Double(bytesTotal))
    }

    var remaining: TimeInterval? {
        guard let bytesPerSecond, bytesPerSecond > 1, bytesTotal > bytesDone, !isPaused else { return nil }
        return Double(bytesTotal - bytesDone) / bytesPerSecond
    }

    var completedCategoryCount: Int {
        categories.filter(\.isComplete).count
    }
}

/// Result shown on S7 and stored in History.
struct TransferOutcome: Equatable {
    var status: TransferStatus
    var role: TransferRole
    var method: TransferMethod
    var counts: [DataCategory: Int] = [:]
    var skippedDuplicates: [DataCategory: Int] = [:]
    var savedFiles = 0
    var failures: [ImportFailure] = []
    var bytes: Int64 = 0
    var duration: TimeInterval = 0
    var peerName = ""
    var created = CreatedIdentifiers()

    var totalCount: Int {
        counts.values.reduce(0, +)
    }
}

/// Moving average of throughput over the last few seconds (TZ §4.9: 5 s).
struct TransferSpeedMeter {
    private var samples: [(time: TimeInterval, bytes: Int64)] = []
    let window: TimeInterval

    init(window: TimeInterval = 5) {
        self.window = window
    }

    /// Adds a sample and returns bytes per second, or nil until there is at least 1 s of data.
    mutating func add(bytes: Int64, at time: TimeInterval) -> Double? {
        if let last = samples.last, bytes < last.bytes {
            samples.removeAll()
        }
        samples.append((time, bytes))
        while samples.count > 2, time - samples[1].time >= window {
            samples.removeFirst()
        }
        guard let first = samples.first, time - first.time >= 1 else { return nil }
        return max(0, Double(bytes - first.bytes) / (time - first.time))
    }

    mutating func reset() {
        samples.removeAll()
    }
}

extension Int64 {
    /// "1.2 GB"
    var byteString: String {
        formatted(.byteCount(style: .file))
    }
}

extension TimeInterval {
    /// "About 3 min" style remaining time.
    var remainingString: String {
        let seconds = Int(self.rounded())
        if seconds < 60 {
            return String(localized: "Less than a minute")
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .short
        let value = formatter.string(from: self) ?? ""
        return String(localized: "About \(value) left")
    }
}
