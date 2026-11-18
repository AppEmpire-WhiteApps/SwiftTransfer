import Foundation
import Network
import os

enum PeerReceiverEvent: Sendable {
    /// Advertising over Bonjour and waiting for a sender.
    case ready(port: UInt16)
    case peerConnected(HelloMessage)
    /// The sender proposed a transfer: show S4d and call `accept(policy:)` or `decline()`.
    case incoming(ManifestMessage, HelloMessage)
    case transferStarted
    case pausedChanged(Bool)
    case reconnecting
    case reconnected
    /// All data received; importing into Contacts/Calendar/Photos/Files.
    case importing
    case completed(ImportReport)
    case failed(PeerError)
    case wrongCodeAttempt(Int)
}

/// Receiver side of the iPhone <-> iPhone/iPad transfer (TZ §4.2.4, §8).
/// Advertises `_swifttransfer._tcp`, accepts one TLS-PSK sender, writes items to a temporary inbox
/// with SHA-256 verification and finally hands them to the importer.
actor PeerReceiverSession {
    struct Configuration: Sendable {
        var device: PeerDeviceInfo
        /// Bonjour advertising; disabled in tests that connect to the port directly.
        var advertise = true
        /// Time to wait for the sender to come back after a disconnect.
        var reconnectTimeout: TimeInterval = 90
        var maxFailedHandshakes = 10
    }

    private enum Phase: Equatable {
        case waiting
        case connected
        case awaitingDecision
        case receiving
        case importing
        case finished
        case failed
    }

    nonisolated let configuration: Configuration
    nonisolated let serviceName: String
    nonisolated let code: String
    nonisolated let salt: Data
    nonisolated let qrPSK: PeerPSK
    nonisolated let events: AsyncStream<PeerReceiverEvent>

    private let importer: any ReceivedItemsImporting
    private let eventContinuation: AsyncStream<PeerReceiverEvent>.Continuation
    private let queue = DispatchQueue(label: "swifttransfer.peer.receiver", qos: .userInitiated)
    private let log = Logger(subsystem: "SwiftTransfer", category: "PeerReceiver")
    private var listener: NWListener?
    private var channel: PeerChannel?
    private var generation = 0
    private var phase: Phase = .waiting
    private var peerHello: HelloMessage?
    private var manifest: ManifestMessage?
    private var policy: DuplicatePolicy = .skip
    private var inbox: URL?
    private var writer: IncomingItemWriter?
    private var received: [Int: URL] = [:]
    private var transferFailures: [Int: String] = [:]
    private var bytesPerItem: [Int: Int64] = [:]
    private var isPaused = false
    private var isReconnecting = false
    private var importDone = 0
    private var importTotal = 0
    private var failedHandshakes = 0
    private var reconnectTask: Task<Void, Never>?

    init(configuration: Configuration, importer: any ReceivedItemsImporting) {
        self.configuration = configuration
        self.importer = importer
        let suffix = TransferBase64URL.encode(TransferSecrets.randomBytes(3)).uppercased()
        self.serviceName = "SwiftTransfer-\(suffix)"
        self.code = TransferSecrets.makeCode()
        self.salt = TransferSecrets.randomBytes(16)
        self.qrPSK = PeerPSK.random()
        let (stream, continuation) = AsyncStream<PeerReceiverEvent>.makeStream(bufferingPolicy: .unbounded)
        self.events = stream
        self.eventContinuation = continuation
    }

    /// Payload for the QR code shown on S4c.
    nonisolated var qrPayload: PeerQRPayload {
        PeerQRPayload(
            v: PeerProtocol.version,
            svc: serviceName,
            psk: TransferBase64URL.encode(qrPSK.key),
            code: code,
            name: configuration.device.name
        )
    }

    nonisolated var codePSK: PeerPSK {
        PeerPSK.derived(code: code, salt: salt)
    }

    // MARK: - Lifecycle

    /// Starts the TLS-PSK listener (and Bonjour advertising). Returns the port.
    @discardableResult
    func start() async throws -> UInt16 {
        let parameters = PeerTLS.parameters(psks: [qrPSK, codePSK])
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            throw PeerError.connectionFailed(error.localizedDescription)
        }
        if configuration.advertise {
            let txt = NWTXTRecord([
                "v": String(PeerProtocol.version),
                "s": TransferBase64URL.encode(salt),
                "n": String(configuration.device.name.prefix(60)),
                "m": configuration.device.model,
            ])
            listener.service = NWListener.Service(name: serviceName, type: PeerProtocol.serviceType, txtRecord: txt)
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            Task {
                await self.accept(connection)
            }
        }
        self.listener = listener
        let resumed = OSAllocatedUnfairLock(initialState: false)
        let queue = self.queue
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            @Sendable func finish(_ result: Result<UInt16, Error>) {
                let first = resumed.withLock { done -> Bool in
                    defer { done = true }
                    return !done
                }
                if first {
                    continuation.resume(with: result)
                }
            }
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                switch state {
                case .ready:
                    finish(.success(listener?.port?.rawValue ?? 0))
                case .waiting(let error), .failed(let error):
                    let mapped: PeerError = PeerTLS.isPolicyDenied(error)
                        ? .localNetworkDenied
                        : .connectionFailed(error.localizedDescription)
                    finish(.failure(mapped))
                    if case .failed = state, let self {
                        Task {
                            await self.fail(mapped)
                        }
                    }
                default:
                    break
                }
            }
            listener.serviceRegistrationUpdateHandler = { _ in }
            listener.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 15) {
                finish(.failure(PeerError.timeout))
            }
        }
        log.info("Peer receiver ready on port \(port)")
        eventContinuation.yield(.ready(port: port))
        return port
    }

    /// User accepted the incoming transfer on S4d.
    func accept(policy: DuplicatePolicy) async {
        guard phase == .awaitingDecision, let channel else { return }
        self.policy = policy
        do {
            inbox = try TransferDiskSpace.makeSessionDirectory(kind: "PeerInbox", session: manifest?.sessionID ?? UUID().uuidString)
            try await channel.send(.accept, AcceptMessage(policy: policy))
            phase = .receiving
            eventContinuation.yield(.transferStarted)
        } catch {
            fail(.connectionLost)
        }
    }

    func decline() async {
        guard let channel else { return }
        try? await channel.send(.reject, RejectMessage(reason: "declined"))
        channel.close()
        finish()
    }

    func setPaused(_ paused: Bool) async {
        guard phase == .receiving, paused != isPaused else { return }
        isPaused = paused
        try? await channel?.send(paused ? .pause : .resume, EmptyMessage())
        eventContinuation.yield(.pausedChanged(paused))
    }

    /// Cancels by the user: tells the sender and stops listening.
    func cancel() async {
        if let channel {
            try? await channel.send(.cancel, EmptyMessage())
            channel.close()
        }
        writer?.discard()
        writer = nil
        finish()
    }

    func progress() -> PeerProgressSnapshot {
        var snapshot = PeerProgressSnapshot.make(
            items: manifest?.items ?? [],
            bytesPerItem: bytesPerItem,
            completed: Set(received.keys),
            failed: Set(transferFailures.keys)
        )
        snapshot.importDone = importDone
        snapshot.importTotal = importTotal
        snapshot.isPaused = isPaused
        snapshot.isReconnecting = isReconnecting
        return snapshot
    }

    private func finish() {
        guard phase != .finished && phase != .failed else { return }
        phase = .finished
        teardown()
    }

    private func fail(_ error: PeerError) {
        guard phase != .finished && phase != .failed else { return }
        phase = .failed
        log.error("Peer receiver failed: \(String(describing: error))")
        writer?.discard()
        writer = nil
        eventContinuation.yield(.failed(error))
        teardown()
        if let inbox {
            try? FileManager.default.removeItem(at: inbox)
        }
    }

    private func teardown() {
        reconnectTask?.cancel()
        reconnectTask = nil
        listener?.cancel()
        listener = nil
        channel?.close()
        channel = nil
        eventContinuation.finish()
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) async {
        guard phase != .finished, phase != .failed else {
            connection.cancel()
            return
        }
        let io = ConnectionIO(connection, queue: queue)
        do {
            try await io.start(timeout: 20)
        } catch {
            io.abort()
            failedHandshakes += 1
            eventContinuation.yield(.wrongCodeAttempt(failedHandshakes))
            if failedHandshakes >= configuration.maxFailedHandshakes, channel == nil {
                fail(.tooManyAttempts)
            }
            return
        }
        generation += 1
        let candidate = PeerChannel(io: io, generation: generation)
        do {
            let first = try await candidate.receive(timeout: 15)
            guard first.type == .hello else {
                throw PeerError.protocolViolation("expected hello")
            }
            let hello = try first.decode(HelloMessage.self)
            let localHello = configuration.device.hello(
                sessionID: hello.sessionID,
                freeSpace: TransferDiskSpace.availableCapacity()
            )
            try await candidate.send(.hello, localHello)
            if let mismatch = hello.incompatibility(with: localHello) {
                try? await candidate.send(.error, ErrorMessage(code: .versionMismatch, message: nil, index: nil))
                candidate.close()
                fail(mismatch)
                return
            }
            if let existing = peerHello, existing.sessionID != hello.sessionID {
                try? await candidate.send(.error, ErrorMessage(code: .busy, message: nil, index: nil))
                candidate.close()
                return
            }
            let isReconnect = peerHello != nil
            channel?.close()
            channel = candidate
            if isReconnect {
                reconnectTask?.cancel()
                reconnectTask = nil
                isReconnecting = false
                eventContinuation.yield(.reconnected)
            } else {
                peerHello = hello
                phase = .connected
                eventContinuation.yield(.peerConnected(hello))
            }
            startReading(candidate)
        } catch {
            candidate.close()
        }
    }

    private func startReading(_ channel: PeerChannel) {
        Task { [weak self] in
            do {
                while true {
                    let frame = try await channel.receive()
                    guard let self else { return }
                    try await self.handle(frame, on: channel)
                }
            } catch {
                await self?.connectionEnded(channel, error: error)
            }
        }
    }

    private func connectionEnded(_ ended: PeerChannel, error: Error) {
        guard ended.generation == channel?.generation else { return }
        channel = nil
        writer?.suspend()
        switch phase {
        case .receiving:
            isReconnecting = true
            eventContinuation.yield(.reconnecting)
            let timeout = configuration.reconnectTimeout
            reconnectTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.reconnectTimedOut()
            }
        case .connected, .awaitingDecision:
            fail(.connectionLost)
        case .waiting, .importing, .finished, .failed:
            break
        }
    }

    private func reconnectTimedOut() {
        guard channel == nil, phase == .receiving else { return }
        fail(.connectionLost)
    }

    // MARK: - Messages

    private func handle(_ frame: WireFrame, on channel: PeerChannel) async throws {
        switch frame.type {
        case .manifest:
            let message = try frame.decode(ManifestMessage.self)
            manifest = message
            phase = .awaitingDecision
            if let peerHello {
                eventContinuation.yield(.incoming(message, peerHello))
            }
        case .itemBegin:
            let message = try frame.decode(ItemBeginMessage.self)
            try await beginItem(message, on: channel)
        case .chunk:
            // Chunks of an item that could not be opened are dropped; its item_end gets a negative ack.
            let header = try frame.decode(ChunkHeader.self)
            guard let writer, writer.index == header.index else { return }
            try writer.append(frame.body)
            bytesPerItem[writer.index] = writer.bytesWritten
        case .itemEnd:
            let message = try frame.decode(ItemEndMessage.self)
            try await endItem(message, on: channel)
        case .error:
            let message = try frame.decode(ErrorMessage.self)
            if let index = message.index {
                transferFailures[index] = message.message ?? message.code.rawValue
                if writer?.index == index {
                    writer?.discard()
                    writer = nil
                }
            } else if message.code == .versionMismatch {
                fail(.versionMismatch(peerNeedsUpdate: false))
            }
        case .pause, .resume:
            isPaused = frame.type == .pause
            eventContinuation.yield(.pausedChanged(isPaused))
        case .cancel:
            fail(.cancelledByPeer)
        case .ping:
            let message = (try? frame.decode(PingMessage.self)) ?? PingMessage(time: 0)
            try await channel.send(.pong, message)
        case .resumeRequest:
            let message = try frame.decode(ResumeRequestMessage.self)
            try await sendResumeState(for: message, on: channel)
        case .done:
            await runImport(on: channel)
        case .hello, .accept, .reject, .ack, .pong, .importReport, .resumeState:
            break
        }
    }

    private func beginItem(_ message: ItemBeginMessage, on channel: PeerChannel) async throws {
        guard phase == .receiving, let manifest, let inbox,
              let item = manifest.items.first(where: { $0.index == message.index })
        else {
            throw PeerError.protocolViolation("unexpected item")
        }
        if let writer, writer.index != message.index {
            writer.discard()
        }
        writer?.suspend()
        let url = inbox
            .appendingPathComponent(String(item.index), isDirectory: true)
            .appendingPathComponent(TransferDiskSpace.sanitizedFileName(item.fileName))
        do {
            writer = try IncomingItemWriter(index: item.index, fileURL: url, offset: message.offset)
            bytesPerItem[item.index] = message.offset
        } catch {
            writer = nil
            try await channel.send(.ack, AckMessage(index: item.index, ok: false, reason: "offset"))
        }
    }

    private func endItem(_ message: ItemEndMessage, on channel: PeerChannel) async throws {
        guard let writer, writer.index == message.index else {
            try await channel.send(.ack, AckMessage(index: message.index, ok: false, reason: "no_item"))
            return
        }
        self.writer = nil
        switch try writer.finish(expectedSHA256: message.sha256) {
        case .verified(let url):
            received[message.index] = url
            transferFailures[message.index] = nil
            try await channel.send(.ack, AckMessage(index: message.index, ok: true, reason: nil))
        case .mismatch:
            bytesPerItem[message.index] = 0
            try await channel.send(.ack, AckMessage(index: message.index, ok: false, reason: "sha256"))
        }
    }

    private func sendResumeState(for request: ResumeRequestMessage, on channel: PeerChannel) async throws {
        guard request.sessionID == peerHello?.sessionID else {
            try await channel.send(.error, ErrorMessage(code: .unknownSession, message: nil, index: nil))
            return
        }
        let state = ResumeStateMessage(
            sessionID: request.sessionID,
            acked: received.keys.sorted(),
            failed: transferFailures.keys.sorted(),
            partialIndex: writer?.index,
            partialOffset: writer?.bytesWritten ?? 0
        )
        try await channel.send(.resumeState, state)
    }

    private func runImport(on channel: PeerChannel) async {
        guard phase == .receiving, let manifest else { return }
        phase = .importing
        eventContinuation.yield(.importing)
        let itemsByIndex = Dictionary(uniqueKeysWithValues: manifest.items.map { ($0.index, $0) })
        let items: [ReceivedItem] = received.keys.sorted().compactMap { index in
            guard let item = itemsByIndex[index], let url = received[index] else { return nil }
            return ReceivedItem(category: item.category, fileURL: url, path: item.path)
        }
        importTotal = items.count
        let report = await importer.importItems(items, policy: policy) { [weak self] done, total in
            Task {
                await self?.setImportProgress(done: done, total: total)
            }
        }
        var merged = report
        for (index, reason) in transferFailures.sorted(by: { $0.key < $1.key }) {
            let item = itemsByIndex[index]
            merged.failures.append(ImportFailure(category: item?.category, path: item?.path ?? "#\(index)", reason: reason))
        }
        try? await channel.send(.importReport, ImportReportMessage(report: merged))
        // The inbox stays until `discardInbox()` so failed items can be imported again.
        eventContinuation.yield(.completed(merged))
        phase = .finished
        try? await Task.sleep(nanoseconds: 500_000_000)
        teardown()
    }

    /// Received files whose import failed (for "Retry failed").
    func receivedItems(forPaths paths: Set<String>) -> [ReceivedItem] {
        guard let manifest else { return [] }
        return manifest.items.compactMap { item in
            guard paths.contains(item.path), let url = received[item.index] else { return nil }
            return ReceivedItem(category: item.category, fileURL: url, path: item.path)
        }
    }

    /// Removes the temporary inbox; call when the result screen closes.
    func discardInbox() {
        if let inbox {
            try? FileManager.default.removeItem(at: inbox)
        }
        inbox = nil
    }

    private func setImportProgress(done: Int, total: Int) {
        importDone = done
        importTotal = total
    }
}
