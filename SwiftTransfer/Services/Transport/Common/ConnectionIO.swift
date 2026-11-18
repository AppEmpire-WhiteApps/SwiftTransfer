import Foundation
import Network
import os

enum ConnectionIOError: Error, Equatable {
    case notReady(String)
    case closed
    case timeout
}

/// async/await wrapper around `NWConnection` used by the web server and the P2P sessions.
final class ConnectionIO: Sendable {
    let connection: NWConnection
    private let queue: DispatchQueue

    init(_ connection: NWConnection, queue: DispatchQueue = DispatchQueue(label: "swifttransfer.connection")) {
        self.connection = connection
        self.queue = queue
    }

    /// Remote IP address (without interface scope) if known.
    var remoteIP: String? {
        guard case .hostPort(let host, _) = connection.endpoint else { return nil }
        return ConnectionIO.ipString(host)
    }

    static func ipString(_ host: NWEndpoint.Host) -> String {
        let text: String
        switch host {
        case .ipv4(let address):
            text = "\(address)"
        case .ipv6(let address):
            text = "\(address)"
        case .name(let name, _):
            text = name
        @unknown default:
            text = "\(host)"
        }
        return text.split(separator: "%").first.map(String.init) ?? text
    }

    /// Starts the connection and waits until it is ready. A `.waiting` state counts as failure.
    func start(
        timeout: TimeInterval = 30,
        onLaterStateChange: (@Sendable (NWConnection.State) -> Void)? = nil
    ) async throws {
        let resumed = OSAllocatedUnfairLock(initialState: false)
        let connection = self.connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            @Sendable func finish(_ result: Result<Void, Error>) {
                let shouldResume = resumed.withLock { done -> Bool in
                    if done { return false }
                    done = true
                    return true
                }
                if shouldResume {
                    continuation.resume(with: result)
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.success(()))
                case .waiting(let error):
                    finish(.failure(error))
                case .failed(let error):
                    finish(.failure(error))
                case .cancelled:
                    finish(.failure(ConnectionIOError.closed))
                default:
                    break
                }
                onLaterStateChange?(state)
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(ConnectionIOError.timeout))
            }
        }
    }

    /// Receives up to `maximum` bytes. Returns nil at end of stream.
    func receive(maximum: Int = 256 * 1024) async throws -> Data? {
        let connection = self.connection
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maximum) { data, _, isComplete, error in
                if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if let error {
                    continuation.resume(throwing: error)
                } else if isComplete {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    /// Sends bytes and waits until the network stack has processed them.
    func send(_ data: Data) async throws {
        let connection = self.connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Graceful close.
    func close() {
        connection.cancel()
    }

    /// Abortive close.
    func abort() {
        connection.forceCancel()
    }
}

/// Runs an async operation with a deadline. `onTimeout` should unblock the operation
/// (e.g. cancel the connection) because network waits ignore task cancellation.
func withTransportDeadline<T: Sendable>(
    seconds: TimeInterval,
    onTimeout: @escaping @Sendable () -> Void,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T?.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        guard let first = try await group.next() else { throw ConnectionIOError.timeout }
        if let value = first {
            group.cancelAll()
            return value
        }
        onTimeout()
        group.cancelAll()
        throw ConnectionIOError.timeout
    }
}
