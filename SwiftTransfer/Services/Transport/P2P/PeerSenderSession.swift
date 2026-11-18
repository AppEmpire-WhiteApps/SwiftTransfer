import Foundation
import Network
import os

enum PeerSenderEvent: Sendable {
    case reconnecting(attempt: Int)
    case reconnected
    case pausedChanged(Bool)
    /// Every item was sent and acknowledged; the receiver is importing.
    case allSent
    case completed(PeerSendResult)
    case failed(PeerError)
}

/// Outcome of a P2P send.
struct PeerSendResult: Sendable, Equatable {
    var sentCount: Int
    var failures: [ImportFailure]
    /// Import report from the receiver; nil if the connection ended before it arrived.
    var report: ImportReport?
}

/// Where and how to connect.
struct PeerTarget: Sendable {
    var endpoint: NWEndpoint
    var psk: PeerPSK
    var displayName: String

    /// From a scanned QR code.
    static func qr(_ payload: PeerQRPayload) -> PeerTarget? {
        guard let key = payload.pskData else { return nil }
        return PeerTarget(
            endpoint: .service(name: payload.svc, type: PeerProtocol.serviceType, domain: "local.", interface: nil),
            psk: PeerPSK(identity: PeerPSK.qrIdentity, key: key),
            displayName: payload.name
        )
    }

    /// From a nearby device and the 6-digit code typed by the user.
    static func discovered(_ peer: DiscoveredPeer, code: String) -> PeerTarget? {
        guard let salt = peer.salt else { return nil }
        return PeerTarget(endpoint: peer.endpoint, psk: .derived(code: code, salt: salt), displayName: peer.name)
    }
}

/// Sender side of the iPhone <-> iPhone/iPad transfer: connects with TLS-PSK, exchanges `hello`,
/// sends the manifest, streams items in 256 KB chunks with SHA-256 and resumes after reconnects.
actor PeerSenderSession {
    nonisolated let target: PeerTarget
    nonisolated let device: PeerDeviceInfo
    nonisolated let sessionID = UUID().uuidString
    nonisolated let events: AsyncStream<PeerSenderEvent>

    private let eventContinuation: AsyncStream<PeerSenderEvent>.Continuation
    private let queue = DispatchQueue(label: "swifttransfer.peer.sender", qos: .userInitiated)
    private let log = Logger(subsystem: "SwiftTransfer", category: "PeerSender")
    private var channel: PeerChannel?
    private var generation = 0
    private var peerHello: HelloMessage?
    private var content: (any TransferContent)?
    private var manifest: ManifestMessage?
    private var acked: Set<Int> = []
    private var unacked: Set<Int> = []
    private var failed: [Int: String] = [:]
    private var attempts: [Int: Int] = [:]
    private var bytesPerItem: [Int: Int64] = [:]
    private var resumeIndex: Int?
    private var resumeOffset: Int64 = 0
    private var isPaused = false
    private var pausedByPeer = false
    private var isCancelled = false
    private var isReconnecting = false
    private var connectionBroken = false
    private var decision: Result<DuplicatePolicy, PeerError>?
    private var report: ImportReport?
    private var reportArrived = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var pingTask: Task<Void, Never>?
    private var finished = false

    init(target: PeerTarget, device: PeerDeviceInfo) {
        self.target = target
        self.device = device
        let (stream, continuation) = AsyncStream<PeerSenderEvent>.makeStream(bufferingPolicy: .unbounded)
        self.events = stream
        self.eventContinuation = continuation
    }

    // MARK: - Public API

    /// Connects, authenticates with the PSK and exchanges `hello`. Returns the receiver's hello.
    @discardableResult
    func connect() async throws -> HelloMessage {
        let hello = try await openChannel()
        startPinging()
        return hello
    }

    /// Sends the manifest, waits for the receiver's decision and streams every item.
    /// Returns when the receiver reported the import (or the transfer failed).
    func send(content: any TransferContent) async -> Result<PeerSendResult, PeerError> {
        let entries = content.entries
        let manifest = ManifestMessage(sessionID: sessionID, entries: entries)
        self.content = content
        self.manifest = manifest
        do {
            guard let channel else { throw PeerError.connectionLost }
            try await channel.send(.manifest, manifest)
            let policy = try await waitForDecision()
            log.info("Receiver accepted with policy \(policy.rawValue)")
            try await transferLoop(entries: entries)
            eventContinuation.yield(.allSent)
            try? await self.channel?.send(.done, DoneMessage(sent: acked.count, failed: failed.keys.sorted()))
            await waitForReport()
            let result = makeResult()
            complete(.completed(result))
            return .success(result)
        } catch let error as PeerError {
            complete(.failed(error))
            return .failure(error)
        } catch {
            let mapped = isCancelled ? PeerError.cancelledByPeer : PeerError.connectionLost
            complete(.failed(mapped))
            return .failure(mapped)
        }
    }

    func setPaused(_ paused: Bool) async {
        guard paused != isPaused else { return }
        isPaused = paused
        try? await channel?.send(paused ? .pause : .resume, EmptyMessage())
        eventContinuation.yield(.pausedChanged(paused || pausedByPeer))
        signal()
    }

    func cancel() async {
        guard !isCancelled else { return }
        isCancelled = true
        if let channel {
            try? await channel.send(.cancel, EmptyMessage())
            channel.close()
        }
        if decision == nil {
            decision = .failure(.cancelledByPeer)
        }
        signal()
        complete(nil)
    }

    func progress() -> PeerProgressSnapshot {
        var snapshot = PeerProgressSnapshot.make(
            items: manifest?.items ?? [],
            bytesPerItem: bytesPerItem,
            completed: acked,
            failed: Set(failed.keys)
        )
        snapshot.isPaused = isPaused || pausedByPeer
        snapshot.isReconnecting = isReconnecting
        return snapshot
    }

    // MARK: - Connection

    private func openChannel() async throws -> HelloMessage {
        let connection = NWConnection(to: target.endpoint, using: PeerTLS.parameters(psks: [target.psk]))
        let io = ConnectionIO(connection, queue: queue)
        do {
            try await io.start(timeout: 20)
        } catch {
            io.abort()
            if PeerTLS.isAuthenticationError(error) {
                throw PeerError.authenticationFailed
            }
            if PeerTLS.isPolicyDenied(error) {
                throw PeerError.localNetworkDenied
            }
            if case ConnectionIOError.timeout = error {
                throw PeerError.timeout
            }
            throw PeerError.connectionFailed(error.localizedDescription)
        }
        generation += 1
        let candidate = PeerChannel(io: io, generation: generation)
        let localHello = device.hello(sessionID: sessionID, freeSpace: nil)
        let reply: WireFrame
        do {
            try await candidate.send(.hello, localHello)
            reply = try await candidate.receive(timeout: 15)
        } catch {
            candidate.close()
            // A PSK mismatch may surface only on the first read.
            if PeerTLS.isAuthenticationError(error) {
                throw PeerError.authenticationFailed
            }
            throw PeerError.connectionFailed(error.localizedDescription)
        }
        if reply.type == .error, let message = try? reply.decode(ErrorMessage.self) {
            candidate.close()
            switch message.code {
            case .versionMismatch: throw PeerError.versionMismatch(peerNeedsUpdate: true)
            case .busy: throw PeerError.busy
            default: throw PeerError.protocolViolation(message.code.rawValue)
            }
        }
        guard reply.type == .hello, let hello = try? reply.decode(HelloMessage.self) else {
            candidate.close()
            throw PeerError.protocolViolation("expected hello")
        }
        if let mismatch = hello.incompatibility(with: localHello) {
            candidate.close()
            throw mismatch
        }
        // The receiver follows an incompatible hello with an error frame; give it a moment.
        peerHello = hello
        channel = candidate
        connectionBroken = false
        startReading(candidate)
        return hello
    }

    private func startReading(_ channel: PeerChannel) {
        Task { [weak self] in
            do {
                while true {
                    let frame = try await channel.receive()
                    guard let self else { return }
                    await self.handle(frame, from: channel)
                }
            } catch {
                await self?.connectionEnded(channel)
            }
        }
    }

    private func connectionEnded(_ ended: PeerChannel) {
        guard ended.generation == channel?.generation else { return }
        connectionBroken = true
        signal()
    }

    private func startPinging() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self, !Task.isCancelled else { return }
                await self.sendPing()
            }
        }
    }

    private func sendPing() async {
        guard !connectionBroken, let channel else { return }
        try? await channel.send(.ping, PingMessage(time: Date().timeIntervalSince1970))
    }

    /// Up to 3 reconnects with exponential pauses, then `resume_request`.
    private func reconnect() async throws {
        channel?.close()
        channel = nil
        isReconnecting = true
        defer { isReconnecting = false }
        var lastError: PeerError = .connectionLost
        for attempt in 1...3 {
            if isCancelled { throw PeerError.cancelledByPeer }
            eventContinuation.yield(.reconnecting(attempt: attempt))
            try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000))
            do {
                _ = try await openChannel()
                guard let channel else { continue }
                try await channel.send(.resumeRequest, ResumeRequestMessage(sessionID: sessionID))
                try await waitForResumeState()
                eventContinuation.yield(.reconnected)
                return
            } catch let error as PeerError {
                lastError = error
                if case .versionMismatch = error { throw error }
            } catch {
                lastError = .connectionLost
            }
        }
        throw lastError == .authenticationFailed ? PeerError.connectionLost : lastError
    }

    private var pendingResumeState: ResumeStateMessage?

    private func waitForResumeState() async throws {
        pendingResumeState = nil
        let deadline = Date().addingTimeInterval(15)
        while pendingResumeState == nil {
            if connectionBroken || Date() > deadline {
                throw PeerError.connectionLost
            }
            await waitForSignal(timeout: 1)
        }
        guard let state = pendingResumeState else { return }
        acked = Set(state.acked)
        for index in state.failed where failed[index] == nil {
            failed[index] = String(localized: "Not received")
        }
        unacked.removeAll()
        resumeIndex = state.partialIndex
        resumeOffset = state.partialOffset
        if let index = state.partialIndex {
            bytesPerItem[index] = state.partialOffset
        }
    }

    // MARK: - Messages

    private func handle(_ frame: WireFrame, from source: PeerChannel) async {
        guard source.generation == channel?.generation else { return }
        switch frame.type {
        case .accept:
            let message = try? frame.decode(AcceptMessage.self)
            decision = .success(message?.policy ?? .skip)
        case .reject:
            let message = try? frame.decode(RejectMessage.self)
            decision = .failure(.rejected(message?.reason ?? ""))
        case .ack:
            guard let message = try? frame.decode(AckMessage.self) else { return }
            unacked.remove(message.index)
            if message.ok {
                acked.insert(message.index)
            } else if attempts[message.index, default: 0] >= PeerProtocol.maxAttempts {
                let reason = String(localized: "Integrity check failed")
                failed[message.index] = reason
                try? await channel?.send(.error, ErrorMessage(code: .readFailed, message: reason, index: message.index))
            } else {
                bytesPerItem[message.index] = 0
            }
        case .pause, .resume:
            pausedByPeer = frame.type == .pause
            eventContinuation.yield(.pausedChanged(isPaused || pausedByPeer))
        case .cancel:
            isCancelled = true
            decision = decision ?? .failure(.cancelledByPeer)
            connectionBroken = true
            complete(.failed(.cancelledByPeer))
        case .ping:
            let message = (try? frame.decode(PingMessage.self)) ?? PingMessage(time: 0)
            try? await channel?.send(.pong, message)
        case .importReport:
            report = (try? frame.decode(ImportReportMessage.self))?.report
            reportArrived = true
        case .resumeState:
            pendingResumeState = try? frame.decode(ResumeStateMessage.self)
        case .error:
            if let message = try? frame.decode(ErrorMessage.self), message.code == .versionMismatch {
                decision = decision ?? .failure(.versionMismatch(peerNeedsUpdate: true))
            }
        case .hello, .manifest, .itemBegin, .chunk, .itemEnd, .done, .pong, .resumeRequest:
            break
        }
        signal()
    }

    // MARK: - Transfer

    private func waitForDecision() async throws -> DuplicatePolicy {
        while true {
            if let decision {
                return try decision.get()
            }
            if connectionBroken {
                throw isCancelled ? PeerError.cancelledByPeer : PeerError.connectionLost
            }
            await waitForSignal(timeout: 5)
        }
    }

    private func nextPendingIndex(_ count: Int) -> Int? {
        if let resumeIndex, !acked.contains(resumeIndex), failed[resumeIndex] == nil, !unacked.contains(resumeIndex) {
            return resumeIndex
        }
        for index in 0..<count where !acked.contains(index) && failed[index] == nil && !unacked.contains(index) {
            return index
        }
        return nil
    }

    private func transferLoop(entries: [TransferEntry]) async throws {
        guard let content else { return }
        while true {
            if isCancelled { throw PeerError.cancelledByPeer }
            if connectionBroken {
                try await reconnect()
                continue
            }
            if isPaused || pausedByPeer {
                await waitForSignal(timeout: 1)
                continue
            }
            guard let index = nextPendingIndex(entries.count) else {
                if unacked.isEmpty {
                    return
                }
                await waitForSignal(timeout: 1)
                continue
            }
            if unacked.count >= PeerProtocol.ackWindow {
                await waitForSignal(timeout: 1)
                continue
            }
            do {
                try await sendItem(index: index, entry: entries[index], content: content)
            } catch let error as PeerError {
                throw error
            } catch is ItemReadFailure {
                continue
            } catch {
                connectionBroken = true
            }
        }
    }

    private struct ItemReadFailure: Error {}
    private struct ConnectionDropped: Error {}

    private func sendItem(index: Int, entry: TransferEntry, content: any TransferContent) async throws {
        guard let channel else { throw ConnectionDropped() }
        let offset = resumeIndex == index ? resumeOffset : 0
        resumeIndex = nil
        resumeOffset = 0
        attempts[index, default: 0] += 1
        bytesPerItem[index] = offset
        try await channel.send(.itemBegin, ItemBeginMessage(index: index, offset: offset, attempt: attempts[index] ?? 1))
        let sentNetwork = OSAllocatedUnfairLock(initialState: false)
        let result: OutgoingItemStreamer.Result
        do {
            result = try await OutgoingItemStreamer.stream(
                content: content,
                entry: entry,
                index: index,
                offset: offset,
                sendChunk: { [weak self] data in
                    do {
                        try await channel.send(.chunk, ChunkHeader(index: index), body: data)
                    } catch {
                        sentNetwork.withLock { $0 = true }
                        throw error
                    }
                    await self?.addBytes(index: index, count: Int64(data.count))
                },
                beforeChunk: { [weak self] in
                    try await self?.waitWhilePaused()
                }
            )
        } catch {
            if sentNetwork.withLock({ $0 }) || error is ConnectionDropped {
                throw ConnectionDropped()
            }
            if error is PeerError {
                throw error
            }
            // Reading the item failed (e.g. iCloud asset unavailable): report and continue.
            let reason = error.localizedDescription
            failed[index] = reason
            try? await channel.send(.error, ErrorMessage(code: .readFailed, message: reason, index: index))
            throw ItemReadFailure()
        }
        do {
            try await channel.send(.itemEnd, ItemEndMessage(index: index, size: result.size, sha256: result.sha256))
        } catch {
            throw ConnectionDropped()
        }
        unacked.insert(index)
    }

    private func addBytes(index: Int, count: Int64) {
        bytesPerItem[index, default: 0] += count
    }

    private func waitWhilePaused() async throws {
        while isPaused || pausedByPeer {
            if isCancelled { throw PeerError.cancelledByPeer }
            if connectionBroken { throw ConnectionDropped() }
            await waitForSignal(timeout: 1)
        }
        if isCancelled { throw PeerError.cancelledByPeer }
    }

    private func waitForReport() async {
        while !reportArrived && !connectionBroken && !isCancelled {
            await waitForSignal(timeout: 5)
        }
    }

    private func makeResult() -> PeerSendResult {
        let items = manifest?.items ?? []
        let failures = failed.sorted { $0.key < $1.key }.map { index, reason in
            let item = items.first { $0.index == index }
            return ImportFailure(category: item?.category, path: item?.path ?? "#\(index)", reason: reason)
        }
        return PeerSendResult(sentCount: acked.count, failures: failures, report: report)
    }

    private func complete(_ event: PeerSenderEvent?) {
        guard !finished else { return }
        finished = true
        pingTask?.cancel()
        pingTask = nil
        if let event {
            eventContinuation.yield(event)
        }
        eventContinuation.finish()
        let channel = self.channel
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            channel?.close()
        }
        signal()
    }

    // MARK: - Signalling

    private func signal() {
        let current = waiters
        waiters.removeAll()
        for waiter in current.values {
            waiter.resume()
        }
    }

    /// Suspends until `signal()` or the timeout, whichever comes first.
    private func waitForSignal(timeout: TimeInterval) async {
        let identifier = UUID()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters[identifier] = continuation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await self?.resumeWaiter(identifier)
            }
        }
    }

    /// Resumes a waiter on timeout unless `signal()` already did.
    private func resumeWaiter(_ identifier: UUID) {
        waiters.removeValue(forKey: identifier)?.resume()
    }
}
