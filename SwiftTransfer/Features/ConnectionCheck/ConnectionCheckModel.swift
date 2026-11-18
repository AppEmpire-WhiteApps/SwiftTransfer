import Foundation
import Observation
import SwiftUI

/// The checks shown on the connection check screen, in order.
enum ConnectionCheckItem: Int, CaseIterable, Identifiable, Sendable {
    case wifi
    case localNetwork
    case powerAndData
    case battery
    case storage
    case peerLink

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .wifi: "Wi-Fi"
        case .localNetwork: "Local network access"
        case .powerAndData: "Low Power and Low Data Mode"
        case .battery: "Battery"
        case .storage: "Free space"
        case .peerLink: "Second device"
        }
    }
}

/// Runs the connection check step by step and keeps the row states for the UI.
@MainActor
@Observable
final class ConnectionCheckModel {
    private(set) var statuses: [ConnectionCheckItem: CheckStatus] = [:]
    private(set) var details: [ConnectionCheckItem: LocalizedStringResource] = [:]
    private(set) var snapshot: DiagnosticsSnapshot?
    private(set) var isRunning = false
    private(set) var peerName: String?
    /// Size used for the time estimate.
    var transferBytes: Int64
    /// Animate status changes (off with Reduce Motion).
    var animatesChanges = true

    private let diagnostics: NetworkDiagnostics
    /// Short pause between rows so each check is visible.
    private let stepPause: Duration

    init(
        transferBytes: Int64 = 5_000_000_000,
        diagnostics: NetworkDiagnostics = NetworkDiagnostics(),
        stepPause: Duration = .milliseconds(450)
    ) {
        self.transferBytes = transferBytes
        self.diagnostics = diagnostics
        self.stepPause = stepPause
        resetRows()
    }

    var assessment: ConnectionAssessment? {
        snapshot.map { ConnectionAssessment(snapshot: $0, transferBytes: transferBytes) }
    }

    var contextInfo: ConnectionCheckContextInfo? {
        snapshot.map { ConnectionCheckContextInfo(snapshot: $0) }
    }

    var localNetworkDenied: Bool {
        snapshot?.localNetwork == .denied || statuses[.localNetwork] == .failed
    }

    func status(of item: ConnectionCheckItem) -> CheckStatus {
        statuses[item] ?? .pending
    }

    /// Runs all checks sequentially (about 15 seconds at most).
    func run(peer: (any PeerLinkTesting)?) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        snapshot = nil
        peerName = peer?.peerName
        resetRows()

        let diagnostics = self.diagnostics
        // The permission probe takes a few seconds, so it starts right away.
        async let localAccess = diagnostics.localNetworkAccess(timeout: 4)
        var result = DiagnosticsSnapshot()

        // 1. Wi-Fi
        begin(.wifi)
        let path = await diagnostics.pathInfo(timeout: 2)
        await pause()
        result.path = path
        finish(.wifi, status: path.isSatisfied && (path.usesWiFi || path.usesWiredEthernet) ? .ok : .warning, detail: wifiDetail(for: path))

        // 2. Local network permission
        begin(.localNetwork)
        let access = await localAccess
        await pause()
        result.localNetwork = access
        switch access {
        case .granted:
            finish(.localNetwork, status: .ok, detail: "Allowed. Devices can find each other.")
        case .denied:
            finish(.localNetwork, status: .failed, detail: "Not allowed. Turn on Local Network for this app in Settings.")
        case .unknown:
            finish(.localNetwork, status: .warning, detail: "Couldn't confirm. If iOS asks for access, tap Allow.")
        }

        // 3. Low Power Mode and Low Data Mode
        begin(.powerAndData)
        await pause()
        result.lowPowerMode = diagnostics.isLowPowerModeEnabled()
        result.vpnActive = diagnostics.isVPNActive()
        finish(.powerAndData, status: result.lowPowerMode || path.isConstrained ? .warning : .ok, detail: powerDetail(lowPower: result.lowPowerMode, path: path))

        // 4. Battery
        begin(.battery)
        await pause()
        let battery = diagnostics.batteryStatus()
        result.batteryLevel = battery.level
        result.isCharging = battery.isCharging
        finish(.battery, status: result.batteryIsLow ? .warning : .ok, detail: batteryDetail(battery))

        // 5. Free space
        begin(.storage)
        await pause()
        result.freeSpaceBytes = diagnostics.freeSpaceBytes()
        finish(.storage, status: result.freeSpaceIsLow ? .warning : .ok, detail: storageDetail(result.freeSpaceBytes))

        // 6. Link to the second device
        if let peer {
            begin(.peerLink)
            let measurement = await diagnostics.measurePeer(peer, timeout: 6)
            result.peerLink = measurement
            if let measurement {
                let grade = ConnectionAssessment.grade(for: result)
                finish(.peerLink, status: grade == .weak ? .warning : .ok, detail: peerDetail(measurement))
            } else {
                finish(.peerLink, status: .warning, detail: "Couldn't measure the speed. Keep both apps open and try again.")
            }
        } else {
            finish(.peerLink, status: .pending, detail: "Connect a second device to measure speed.")
        }

        guard !Task.isCancelled else { return }
        withOptionalAnimation {
            snapshot = result
        }
    }

    /// A short summary for the assistant draft, without personal data.
    func assistantDraft() -> String {
        guard let snapshot, let assessment else {
            return String(localized: "Can you help me check the connection between my devices?")
        }
        var facts: [String] = [String(localized: assessment.grade.title)]
        facts.append(snapshot.wifiConnected ? String(localized: "Wi-Fi connected") : String(localized: "no Wi-Fi"))
        if snapshot.localNetwork == .denied {
            facts.append(String(localized: "local network access denied"))
        }
        if snapshot.lowPowerMode {
            facts.append(String(localized: "Low Power Mode on"))
        }
        if snapshot.lowDataMode {
            facts.append(String(localized: "Low Data Mode on"))
        }
        if let link = snapshot.peerLink {
            let speed = Int(link.throughputMbps.rounded())
            let rtt = Int(link.rttMilliseconds.rounded())
            facts.append(String(localized: "speed \(speed) Mbit/s, latency \(rtt) ms"))
        }
        let summary = facts.joined(separator: ", ")
        return String(localized: "My connection check result: \(summary). How can I make the transfer faster and more reliable?")
    }

    // MARK: - Steps

    private func resetRows() {
        for item in ConnectionCheckItem.allCases {
            statuses[item] = .pending
            details[item] = nil
        }
    }

    private func begin(_ item: ConnectionCheckItem) {
        withOptionalAnimation {
            statuses[item] = .running
        }
    }

    private func finish(_ item: ConnectionCheckItem, status: CheckStatus, detail: LocalizedStringResource) {
        withOptionalAnimation {
            statuses[item] = status
            details[item] = detail
        }
    }

    private func pause() async {
        try? await Task.sleep(for: stepPause)
    }

    private func withOptionalAnimation(_ changes: () -> Void) {
        if animatesChanges {
            withAnimation(.spring(duration: 0.35, bounce: 0.25), changes)
        } else {
            changes()
        }
    }

    // MARK: - Details

    private func wifiDetail(for path: NetworkPathInfo) -> LocalizedStringResource {
        if path.isSatisfied && path.usesWiFi {
            return path.isExpensive
                ? "Connected to a Personal Hotspot. That works for the transfer."
                : "Connected to Wi-Fi."
        }
        if path.isSatisfied && path.usesWiredEthernet {
            return "Connected by Ethernet."
        }
        if path.usesCellular {
            return "Not on Wi-Fi. Join the same Wi-Fi as the other device, or turn on Personal Hotspot on one phone and connect the other one to it."
        }
        return "Not connected to Wi-Fi. Turn on Wi-Fi or use Personal Hotspot."
    }

    private func powerDetail(lowPower: Bool, path: NetworkPathInfo) -> LocalizedStringResource {
        switch (lowPower, path.isConstrained) {
        case (true, true): "Low Power Mode and Low Data Mode are on. They can slow down the transfer."
        case (true, false): "Low Power Mode is on. It can slow down the transfer."
        case (false, true): "Low Data Mode is on for this network. It can slow down the transfer."
        case (false, false): "Both are off."
        }
    }

    private func batteryDetail(_ battery: DiagnosticsBatteryStatus) -> LocalizedStringResource {
        guard let level = battery.level else {
            return "Battery level isn't available on this device."
        }
        let percent = level.formatted(.percent.precision(.fractionLength(0)))
        if battery.isCharging {
            return "\(percent), charging."
        }
        if level < ConnectionAssessment.lowBatteryLevel {
            return "\(percent). Connect a charger before a long transfer."
        }
        return "\(percent)."
    }

    private func storageDetail(_ bytes: Int64?) -> LocalizedStringResource {
        guard let bytes else {
            return "Couldn't read free space."
        }
        let size = bytes.formatted(.byteCount(style: .file))
        if bytes < ConnectionAssessment.lowFreeSpaceBytes {
            return "Only \(size) available on this device."
        }
        return "\(size) available on this device."
    }

    private func peerDetail(_ link: PeerLinkMeasurement) -> LocalizedStringResource {
        let speed = (Int64(link.throughputBytesPerSecond)).formatted(.byteCount(style: .file))
        let rtt = Int(link.rttMilliseconds.rounded())
        if let peerName {
            return "\(peerName): \(speed)/s, latency \(rtt) ms."
        }
        return "\(speed)/s, latency \(rtt) ms."
    }
}
