import CFNetwork
import Foundation
import Network
import os
import UIKit

/// Battery state read from `UIDevice`.
struct DiagnosticsBatteryStatus: Sendable, Equatable {
    /// 0...1, nil when unknown (e.g. Simulator).
    var level: Double?
    var isCharging: Bool
}

/// Probes the device state used by the connection check. Every probe is bounded by a timeout.
struct NetworkDiagnostics: Sendable {
    /// Bonjour service type advertised by the P2P transport (also listed in NSBonjourServices).
    static let serviceType = "_swifttransfer._tcp"
    /// `kDNSServiceErr_PolicyDenied`: the user denied local network access.
    static let policyDeniedCode: Int32 = -65570

    /// Current network path: Wi-Fi, cellular, Low Data Mode, expensive network.
    func pathInfo(timeout: TimeInterval = 2) async -> NetworkPathInfo {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "SwiftTransfer.Diagnostics.Path")
        let gate = DiagnosticsResumeGate<NetworkPathInfo>()
        let info = await withCheckedContinuation { (continuation: CheckedContinuation<NetworkPathInfo, Never>) in
            gate.install(continuation)
            monitor.pathUpdateHandler = { path in
                gate.resume(with: Self.makeInfo(from: path))
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                gate.resume(with: .unavailable)
            }
        }
        monitor.cancel()
        return info
    }

    /// Probes local network permission with a short Bonjour browse for `_swifttransfer._tcp`.
    /// The first call may show the system permission prompt.
    func localNetworkAccess(timeout: TimeInterval = 4) async -> LocalNetworkAccess {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: "local."), using: parameters)
        let queue = DispatchQueue(label: "SwiftTransfer.Diagnostics.LocalNetwork")
        let probe = DiagnosticsLocalNetworkProbe()
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<LocalNetworkAccess, Never>) in
            probe.gate.install(continuation)
            browser.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    probe.markReady()
                case .waiting(let error):
                    if Self.isPolicyDenied(error) {
                        probe.markDenied()
                    }
                case .failed(let error):
                    probe.gate.resume(with: Self.isPolicyDenied(error) ? .denied : .unknown)
                default:
                    break
                }
            }
            browser.browseResultsChangedHandler = { results, _ in
                if !results.isEmpty {
                    probe.gate.resume(with: .granted)
                }
            }
            browser.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                probe.gate.resume(with: probe.verdictAtTimeout())
            }
        }
        browser.cancel()
        return result
    }

    func isLowPowerModeEnabled() -> Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    /// Heuristic: a tunnel interface carries scoped proxy settings while a VPN is connected.
    func isVPNActive() -> Bool {
        guard
            let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
            let scoped = settings["__SCOPED__"] as? [String: Any]
        else {
            return false
        }
        let markers = ["tap", "tun", "ppp", "ipsec"]
        return scoped.keys.contains { key in
            let name = key.lowercased()
            return markers.contains { name.contains($0) }
        }
    }

    /// Free space available for important data (photos, imports) on this device.
    func freeSpaceBytes() -> Int64? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    @MainActor
    func batteryStatus() -> DiagnosticsBatteryStatus {
        let device = UIDevice.current
        let wasMonitoring = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        let state = device.batteryState
        device.isBatteryMonitoringEnabled = wasMonitoring
        return DiagnosticsBatteryStatus(
            level: level < 0 ? nil : Double(level),
            isCharging: state == .charging || state == .full
        )
    }

    /// Measures the link to the connected device; nil on error or after `timeout`.
    func measurePeer(_ tester: any PeerLinkTesting, timeout: TimeInterval = 6) async -> PeerLinkMeasurement? {
        await withTaskGroup(of: PeerLinkMeasurement?.self) { group in
            group.addTask {
                try? await tester.measureLink()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    static func isPolicyDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error {
            return Int32(code) == policyDeniedCode
        }
        return false
    }

    private static func makeInfo(from path: NWPath) -> NetworkPathInfo {
        NetworkPathInfo(
            isSatisfied: path.status == .satisfied,
            usesWiFi: path.usesInterfaceType(.wifi),
            usesCellular: path.usesInterfaceType(.cellular),
            usesWiredEthernet: path.usesInterfaceType(.wiredEthernet),
            isConstrained: path.isConstrained,
            isExpensive: path.isExpensive
        )
    }
}

/// Resumes a continuation exactly once, from whichever callback comes first.
private final class DiagnosticsResumeGate<Value: Sendable>: Sendable {
    private let continuation = OSAllocatedUnfairLock<CheckedContinuation<Value, Never>?>(initialState: nil)

    func install(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation.withLock { $0 = continuation }
    }

    func resume(with value: Value) {
        let pending = continuation.withLock { stored -> CheckedContinuation<Value, Never>? in
            let current = stored
            stored = nil
            return current
        }
        pending?.resume(returning: value)
    }
}

/// Collects NWBrowser states for the local network permission probe.
private final class DiagnosticsLocalNetworkProbe: Sendable {
    private struct State {
        var sawReady = false
        var denied = false
    }

    let gate = DiagnosticsResumeGate<LocalNetworkAccess>()
    private let state = OSAllocatedUnfairLock(initialState: State())

    func markReady() {
        state.withLock {
            $0.sawReady = true
            $0.denied = false
        }
    }

    func markDenied() {
        state.withLock { $0.denied = true }
    }

    /// iOS may report PolicyDenied while the permission prompt is still open, so the latest state wins.
    func verdictAtTimeout() -> LocalNetworkAccess {
        state.withLock { current in
            if current.denied {
                return .denied
            }
            return current.sawReady ? .granted : .unknown
        }
    }
}
