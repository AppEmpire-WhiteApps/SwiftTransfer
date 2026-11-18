import Foundation
import Network
import Observation
import os

/// A receiver found nearby over Bonjour.
struct DiscoveredPeer: Identifiable, Hashable, Sendable {
    /// Bonjour service name.
    var id: String
    var name: String
    var model: String?
    /// HKDF salt from the TXT record (needed to derive the PSK from the code).
    var salt: Data?
    var endpoint: NWEndpoint
}

/// Browses `_swifttransfer._tcp` receivers for the "Nearby devices" list (S4b).
@MainActor
@Observable
final class PeerBrowser {
    enum State: Equatable {
        case idle
        case browsing
        case localNetworkDenied
        case failed(String)
    }

    private(set) var peers: [DiscoveredPeer] = []
    private(set) var state: State = .idle
    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private let queue = DispatchQueue(label: "swifttransfer.peer.browser")

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: PeerProtocol.serviceType, domain: nil),
            using: parameters
        )
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.update(state)
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let peers = results.compactMap(PeerBrowser.peer(from:))
            Task { @MainActor in
                self?.peers = peers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        }
        self.browser = browser
        state = .browsing
        browser.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        if state == .browsing {
            state = .idle
        }
    }

    /// Finds a peer by its Bonjour service name (from a QR payload).
    func peer(named serviceName: String) -> DiscoveredPeer? {
        peers.first { $0.id == serviceName }
    }

    private func update(_ newState: NWBrowser.State) {
        switch newState {
        case .ready, .setup:
            state = .browsing
        case .waiting(let error), .failed(let error):
            if PeerTLS.isPolicyDenied(error) {
                state = .localNetworkDenied
            } else if case .failed = newState {
                state = .failed(error.localizedDescription)
            }
        case .cancelled:
            break
        @unknown default:
            break
        }
    }

    nonisolated static func peer(from result: NWBrowser.Result) -> DiscoveredPeer? {
        guard case .service(let name, _, _, _) = result.endpoint else { return nil }
        var displayName = name
        var model: String?
        var salt: Data?
        if case .bonjour(let txt) = result.metadata {
            if let value = txt["n"], !value.isEmpty {
                displayName = value
            }
            model = txt["m"]
            salt = txt["s"].flatMap(TransferBase64URL.decode)
        }
        return DiscoveredPeer(id: name, name: displayName, model: model, salt: salt, endpoint: result.endpoint)
    }
}

/// Detects a denied Local Network permission (and triggers the system prompt on first use).
enum PeerLocalNetworkCheck {
    /// Returns false only when the system reports the permission as denied within `timeout`.
    static func isDenied(timeout: TimeInterval = 2.5) async -> Bool {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: PeerProtocol.serviceType, domain: nil), using: parameters)
        let queue = DispatchQueue(label: "swifttransfer.localnetwork.probe")
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let resumed = OneShotFlag()
            browser.stateUpdateHandler = { state in
                switch state {
                case .waiting(let error), .failed(let error):
                    if PeerTLS.isPolicyDenied(error), resumed.claim() {
                        continuation.resume(returning: true)
                    }
                default:
                    break
                }
            }
            browser.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                if resumed.claim() {
                    continuation.resume(returning: false)
                }
            }
        }
        browser.cancel()
        return result
    }
}

/// One-shot flag: the first `claim()` returns true.
final class OneShotFlag: Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)

    func claim() -> Bool {
        lock.withLock { claimed -> Bool in
            defer { claimed = true }
            return !claimed
        }
    }
}
