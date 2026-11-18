import Foundation
import Observation

/// Whether the app may talk to devices on the local network (iOS "Local Network" privacy setting).
enum LocalNetworkAccess: String, Sendable, Equatable {
    case granted
    case denied
    /// The probe finished without a clear answer (e.g. the permission prompt is still open).
    case unknown
}

/// A Sendable summary of the current network path.
struct NetworkPathInfo: Sendable, Equatable {
    var isSatisfied: Bool
    var usesWiFi: Bool
    var usesCellular: Bool
    var usesWiredEthernet: Bool
    /// Low Data Mode is on for the current network.
    var isConstrained: Bool
    /// Cellular or Personal Hotspot network.
    var isExpensive: Bool

    static let wifi = NetworkPathInfo(
        isSatisfied: true,
        usesWiFi: true,
        usesCellular: false,
        usesWiredEthernet: false,
        isConstrained: false,
        isExpensive: false
    )

    static let unavailable = NetworkPathInfo(
        isSatisfied: false,
        usesWiFi: false,
        usesCellular: false,
        usesWiredEthernet: false,
        isConstrained: false,
        isExpensive: false
    )
}

/// Result of measuring the link to a connected second device.
struct PeerLinkMeasurement: Sendable, Equatable {
    /// Median round-trip time of ping-pong messages.
    var rttMilliseconds: Double
    var throughputBytesPerSecond: Double
    /// Share of lost or retried messages, 0...1.
    var lossRate: Double = 0

    var throughputMbps: Double {
        throughputBytesPerSecond * 8 / 1_000_000
    }
}

/// Measures the link to a connected second device (RTT and throughput).
/// Implemented by the transport layer and registered in `PeerLinkRegistry.shared` while a device is connected.
protocol PeerLinkTesting: Sendable {
    /// Display name of the connected device, e.g. "Anna's iPhone".
    var peerName: String { get }

    /// Runs the RTT (10 ping-pong messages, median) and speed test (about 5 s / up to 50 MB).
    func measureLink() async throws -> PeerLinkMeasurement
}

/// Holds the link tester of the currently connected second device, if any.
@MainActor
@Observable
final class PeerLinkRegistry {
    static let shared = PeerLinkRegistry()

    /// Set by the transport layer when a second device connects; reset to nil on disconnect.
    var current: (any PeerLinkTesting)?
}

/// Everything the connection check measured. Pure data, used for grading and tests.
struct DiagnosticsSnapshot: Sendable, Equatable {
    var path: NetworkPathInfo = .wifi
    var localNetwork: LocalNetworkAccess = .granted
    var lowPowerMode = false
    /// A VPN interface seems to be active.
    var vpnActive = false
    /// 0...1, nil when unknown (e.g. Simulator).
    var batteryLevel: Double?
    var isCharging = false
    var freeSpaceBytes: Int64?
    var peerLink: PeerLinkMeasurement?

    var wifiConnected: Bool {
        path.isSatisfied && (path.usesWiFi || path.usesWiredEthernet)
    }

    var lowDataMode: Bool {
        path.isConstrained
    }

    var batteryIsLow: Bool {
        guard let batteryLevel else { return false }
        return batteryLevel < ConnectionAssessment.lowBatteryLevel && !isCharging
    }

    var freeSpaceIsLow: Bool {
        guard let freeSpaceBytes else { return false }
        return freeSpaceBytes < ConnectionAssessment.lowFreeSpaceBytes
    }
}

/// Overall result of the connection check.
enum ConnectionGrade: Int, Comparable, Sendable, CaseIterable {
    case weak = 0
    case good
    case excellent

    static func < (lhs: ConnectionGrade, rhs: ConnectionGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: LocalizedStringResource {
        switch self {
        case .excellent: "Excellent connection"
        case .good: "Good connection"
        case .weak: "Weak connection"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .excellent: "Everything is ready for a fast transfer."
        case .good: "You can transfer now. A few changes will make it faster."
        case .weak: "The transfer may be slow or fail. Follow the tips below."
        }
    }

    var systemImage: String {
        switch self {
        case .excellent: "checkmark.seal.fill"
        case .good: "hand.thumbsup.fill"
        case .weak: "exclamationmark.triangle.fill"
        }
    }

    /// Value used in the assistant draft and context.
    var contextValue: String {
        switch self {
        case .excellent: "excellent"
        case .good: "good"
        case .weak: "weak"
        }
    }
}

/// A personalized tip shown under the result.
enum ConnectionRecommendation: String, Sendable, CaseIterable, Identifiable {
    case allowLocalNetwork
    case connectWiFi
    case usePersonalHotspot
    case turnOffLowPowerMode
    case turnOffLowDataMode
    case turnOffVPN
    case moveCloser
    case use5GHz
    case chargeBattery
    case freeUpSpace
    case useDrive

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .allowLocalNetwork: "Allow local network access"
        case .connectWiFi: "Connect to Wi-Fi"
        case .usePersonalHotspot: "Use Personal Hotspot"
        case .turnOffLowPowerMode: "Turn off Low Power Mode"
        case .turnOffLowDataMode: "Turn off Low Data Mode"
        case .turnOffVPN: "Turn off VPN"
        case .moveCloser: "Move the devices closer"
        case .use5GHz: "Switch to 5 GHz Wi-Fi"
        case .chargeBattery: "Charge your phone"
        case .freeUpSpace: "Free up space"
        case .useDrive: "Use an external drive"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .allowLocalNetwork:
            "Open this app's settings in iOS Settings and turn on Local Network. Without it the devices can't find each other."
        case .connectWiFi:
            "Connect both devices to the same Wi-Fi network."
        case .usePersonalHotspot:
            "No good Wi-Fi? Turn on Personal Hotspot on one phone and connect the other one to it. Mobile data isn't used for the transfer."
        case .turnOffLowPowerMode:
            "Low Power Mode slows down the network. Turn it off in Control Center or Settings › Battery."
        case .turnOffLowDataMode:
            "Low Data Mode limits network use. Turn it off in the Wi-Fi network settings."
        case .turnOffVPN:
            "A VPN can block or slow down local connections. Turn it off during the transfer."
        case .moveCloser:
            "Keep both devices in the same room, close to each other and to the router."
        case .use5GHz:
            "If your router has a 5 GHz network, connect both devices to it — it's usually much faster."
        case .chargeBattery:
            "The battery is low. Connect a charger so the transfer isn't interrupted."
        case .freeUpSpace:
            "There is little free space on this device. Make sure the receiving device has enough room."
        case .useDrive:
            "For a large library, saving to a USB drive can be faster and more reliable."
        }
    }

    var systemImage: String {
        switch self {
        case .allowLocalNetwork: "lock.shield"
        case .connectWiFi: "wifi"
        case .usePersonalHotspot: "personalhotspot"
        case .turnOffLowPowerMode: "battery.25"
        case .turnOffLowDataMode: "arrow.up.arrow.down"
        case .turnOffVPN: "network.badge.shield.half.filled"
        case .moveCloser: "arrow.left.and.right"
        case .use5GHz: "antenna.radiowaves.left.and.right"
        case .chargeBattery: "bolt.fill"
        case .freeUpSpace: "internaldrive"
        case .useDrive: "externaldrive"
        }
    }
}

/// Grades a diagnostics snapshot, estimates the transfer time and builds recommendations.
struct ConnectionAssessment: Sendable, Equatable {
    /// Speed assumed when no second device was measured: 15 MB/s.
    static let defaultThroughput: Double = 15_000_000
    static let lowBatteryLevel = 0.3
    static let lowFreeSpaceBytes: Int64 = 2_000_000_000
    /// Above this estimated duration an external drive is suggested.
    static let longTransferSeconds: TimeInterval = 3600

    let grade: ConnectionGrade
    let throughputBytesPerSecond: Double
    let isMeasured: Bool
    let transferBytes: Int64
    let recommendations: [ConnectionRecommendation]

    init(snapshot: DiagnosticsSnapshot, transferBytes: Int64) {
        let measurement = snapshot.peerLink
        let throughput = measurement.map { max($0.throughputBytesPerSecond, 1) } ?? Self.defaultThroughput
        let grade = Self.grade(for: snapshot)
        self.grade = grade
        self.throughputBytesPerSecond = throughput
        self.isMeasured = measurement != nil
        self.transferBytes = max(transferBytes, 0)
        let duration = Double(max(transferBytes, 0)) / throughput
        self.recommendations = Self.recommendations(for: snapshot, grade: grade, duration: duration)
    }

    /// Estimated transfer duration in seconds for `transferBytes`.
    var estimatedDuration: TimeInterval {
        estimatedDuration(forBytes: transferBytes)
    }

    func estimatedDuration(forBytes bytes: Int64) -> TimeInterval {
        Double(max(bytes, 0)) / throughputBytesPerSecond
    }

    static func grade(for snapshot: DiagnosticsSnapshot) -> ConnectionGrade {
        if !snapshot.wifiConnected || snapshot.localNetwork == .denied {
            return .weak
        }
        if let link = snapshot.peerLink {
            var grade: ConnectionGrade
            if link.throughputBytesPerSecond >= 20_000_000 && link.rttMilliseconds <= 20 {
                grade = .excellent
            } else if link.throughputBytesPerSecond >= 6_000_000 && link.rttMilliseconds <= 60 {
                grade = .good
            } else {
                grade = .weak
            }
            if link.lossRate > 0.05, let lower = ConnectionGrade(rawValue: grade.rawValue - 1) {
                grade = lower
            }
            return grade
        }
        if snapshot.lowPowerMode || snapshot.lowDataMode {
            return .good
        }
        return .excellent
    }

    static func recommendations(
        for snapshot: DiagnosticsSnapshot,
        grade: ConnectionGrade,
        duration: TimeInterval
    ) -> [ConnectionRecommendation] {
        var result: [ConnectionRecommendation] = []
        func add(_ item: ConnectionRecommendation) {
            if !result.contains(item) {
                result.append(item)
            }
        }

        if snapshot.localNetwork == .denied {
            add(.allowLocalNetwork)
        }
        if !snapshot.wifiConnected {
            add(.connectWiFi)
            add(.usePersonalHotspot)
        }
        if snapshot.lowPowerMode {
            add(.turnOffLowPowerMode)
        }
        if snapshot.lowDataMode {
            add(.turnOffLowDataMode)
        }
        if snapshot.vpnActive {
            add(.turnOffVPN)
        }
        if snapshot.peerLink != nil && grade < .excellent && snapshot.wifiConnected {
            add(.moveCloser)
            add(.use5GHz)
            add(.usePersonalHotspot)
        }
        if snapshot.batteryIsLow {
            add(.chargeBattery)
        }
        if snapshot.freeSpaceIsLow {
            add(.freeUpSpace)
        }
        if duration > longTransferSeconds {
            add(.useDrive)
        }
        return result
    }
}

extension ConnectionCheckContextInfo {
    /// Technical summary for the assistant context (no personal data).
    init(snapshot: DiagnosticsSnapshot) {
        let access: Bool? = switch snapshot.localNetwork {
        case .granted: true
        case .denied: false
        case .unknown: nil
        }
        self.init(
            wifi: snapshot.wifiConnected,
            localNetworkPermission: access,
            rttMs: snapshot.peerLink.map { Int($0.rttMilliseconds.rounded()) },
            throughputMbps: snapshot.peerLink.map { Int($0.throughputMbps.rounded()) },
            lowPower: snapshot.lowPowerMode
        )
    }
}
