import Foundation
import Network
import os

/// Built-in HTTP server for iPhone <-> Android transfers through the phone's browser (TZ §4.2.2, §4.2.3).
///
/// - Listens with `NWListener` (TCP, system-chosen port, never on cellular interfaces).
/// - Session secrets: 128-bit token in the URL and a 6-digit code for manual entry.
/// - Each new client IP must be approved on the iPhone before any data is served.
/// - Download mode serves the manifest, single files (with Range) and streamed ZIP archives.
/// - Upload mode streams multipart uploads to a protected temporary folder.
actor WebReceiverServer {
    struct Configuration: Sendable {
        var mode: WebReceiverMode
        var deviceName: String
        var idleTimeout: TimeInterval = 600
        var logoPNG: Data?
        /// Read the current shared entitlement at the transfer boundary. Photos fail closed by default.
        var allowsPhotoTransfer: @Sendable () async -> Bool = { false }
    }

    enum ClientState: String, Sendable {
        case pending
        case approved
        case denied
    }

    nonisolated let configuration: Configuration
    nonisolated let content: (any TransferContent)?
    nonisolated let entries: [TransferEntry]
    nonisolated let token: String
    nonisolated let code: String
    nonisolated let uploadDirectory: URL?
    nonisolated let events: AsyncStream<WebReceiverEvent>

    private static let maxCodeAttempts = 10
    private let log = Logger(subsystem: "SwiftTransfer", category: "WebReceiver")
    private let eventContinuation: AsyncStream<WebReceiverEvent>.Continuation
    private let queue = DispatchQueue(label: "swifttransfer.webreceiver", qos: .userInitiated)
    private var listener: NWListener?
    private var port: UInt16?
    private var connections: [ObjectIdentifier: ConnectionIO] = [:]
    private var clients: [String: ClientState] = [:]
    private var failedCodeAttempts: [String: Int] = [:]
    private var delivered: [Int: Int64] = [:]
    private var completedEntries: Set<Int> = []
    private var failures: [ImportFailure] = []
    private var activeTransfers = 0
    private var lastActivity = Date()
    private var isStopped = false
    private var idleTask: Task<Void, Never>?
    private var plannedUploadBytes: Int64 = 0
    private var receivedUploadBytes: Int64 = 0
    private var receivedItems: [ReceivedItem] = []
    private var reportedItemCount = 0

    /// Download mode: `content` is required. Upload mode: files go to a new temporary folder.
    init(configuration: Configuration, content: (any TransferContent)?) throws {
        if configuration.mode == .download, content == nil {
            throw WebReceiverError.missingContent
        }
        self.configuration = configuration
        self.content = content
        self.entries = content?.entries ?? []
        self.token = TransferSecrets.makeToken()
        self.code = TransferSecrets.makeCode()
        if configuration.mode == .upload {
            self.uploadDirectory = try TransferDiskSpace.makeSessionDirectory(kind: "WebUploads")
        } else {
            self.uploadDirectory = nil
        }
        let (stream, continuation) = AsyncStream<WebReceiverEvent>.makeStream(bufferingPolicy: .unbounded)
        self.events = stream
        self.eventContinuation = continuation
    }

    // MARK: - Lifecycle

    /// Starts listening and returns the address to show in the QR code.
    func start() async throws -> WebReceiverEndpoint {
        let parameters = NWParameters.tcp
        parameters.prohibitedInterfaceTypes = [.cellular]
        parameters.allowLocalEndpointReuse = true
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            throw WebReceiverError.listenerFailed(error.localizedDescription)
        }
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            Task {
                await self.accept(connection)
            }
        }
        let resumed = OSAllocatedUnfairLock(initialState: false)
        let queue = self.queue
        let readyPort: UInt16 = try await withCheckedThrowingContinuation { continuation in
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
                case .failed(let error):
                    finish(.failure(WebReceiverServer.map(error)))
                    if let self {
                        Task {
                            await self.stop(reason: .failed(error.localizedDescription))
                        }
                    }
                case .waiting(let error):
                    if WebReceiverServer.isPolicyDenied(error) {
                        finish(.failure(WebReceiverError.localNetworkDenied))
                    }
                default:
                    break
                }
            }
            listener.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 15) {
                finish(.failure(WebReceiverError.listenerFailed("timeout")))
            }
        }
        port = readyPort
        lastActivity = Date()
        startIdleTimer()
        log.info("Web receiver listening on port \(readyPort)")
        return endpoint() ?? WebReceiverEndpoint(host: nil, port: readyPort, token: token, code: code)
    }

    /// Current address (the IP may change when Wi-Fi or the hotspot changes).
    func endpoint() -> WebReceiverEndpoint? {
        guard let port else { return nil }
        let address = NetworkInterfaces.preferredIPv4()
        return WebReceiverEndpoint(host: address?.ip, hostKind: address?.kind, port: port, token: token, code: code)
    }

    func stop(reason: WebReceiverStopReason) {
        guard !isStopped else { return }
        isStopped = true
        listener?.cancel()
        listener = nil
        for connection in connections.values {
            connection.abort()
        }
        connections.removeAll()
        idleTask?.cancel()
        idleTask = nil
        log.info("Web receiver stopped")
        eventContinuation.yield(.stopped(reason))
        eventContinuation.finish()
    }

    var stopped: Bool { isStopped }

    // MARK: - Approval

    func approve(client: String) {
        clients[client] = .approved
        eventContinuation.yield(.clientApproved(client: client))
    }

    func deny(client: String) {
        clients[client] = .denied
    }

    private func registerClient(_ ip: String) -> ClientState {
        if let state = clients[ip] {
            return state
        }
        clients[ip] = .pending
        eventContinuation.yield(.approvalRequested(client: ip))
        return .pending
    }

    private func checkCode(_ candidate: String, from ip: String) -> CodeResult {
        let attempts = failedCodeAttempts[ip, default: 0]
        guard attempts < Self.maxCodeAttempts else { return .locked }
        if TransferSecrets.constantTimeEquals(candidate, code) {
            return .accepted
        }
        failedCodeAttempts[ip] = attempts + 1
        return attempts + 1 >= Self.maxCodeAttempts ? .locked : .wrong
    }

    enum CodeResult {
        case accepted
        case wrong
        case locked
    }

    // MARK: - Progress

    func progress() -> WebTransferProgress {
        var result = WebTransferProgress()
        result.activeTransfers = activeTransfers
        result.approvedClients = clients.values.filter { $0 == .approved }.count
        result.failures = failures
        result.lastActivity = lastActivity
        switch configuration.mode {
        case .download:
            for (index, entry) in entries.enumerated() {
                let sent = delivered[index] ?? 0
                let total = entry.byteCount ?? (completedEntries.contains(index) ? sent : 0)
                let done = min(sent, total)
                result.bytesDone += done
                result.bytesTotal += total
                result.categoryBytesDone[entry.category, default: 0] += done
                result.categoryBytesTotal[entry.category, default: 0] += total
                result.categoryItemsTotal[entry.category, default: 0] += 1
                if completedEntries.contains(index) {
                    result.categoryItemsDone[entry.category, default: 0] += 1
                }
            }
        case .upload:
            result.bytesDone = receivedUploadBytes
            result.bytesTotal = max(plannedUploadBytes, receivedUploadBytes)
            result.receivedFiles = receivedItems.count
            for item in receivedItems {
                let category = item.category ?? TransferDiskSpace.guessCategory(forFileName: item.path)
                result.categoryItemsDone[category, default: 0] += 1
                result.categoryItemsTotal[category, default: 0] += 1
            }
        }
        return result
    }

    /// Items received so far in upload mode.
    func uploadedItems() -> [ReceivedItem] {
        receivedItems
    }

    private func recordDelivered(index: Int, upTo offset: Int64) {
        lastActivity = Date()
        delivered[index] = max(delivered[index] ?? 0, offset)
    }

    private func markCompleted(index: Int) {
        completedEntries.insert(index)
    }

    private func recordFailure(_ failure: ImportFailure) {
        if !failures.contains(failure) {
            failures.append(failure)
        }
    }

    private func transferStarted() {
        activeTransfers += 1
        lastActivity = Date()
    }

    private func transferEnded() {
        activeTransfers = max(0, activeTransfers - 1)
        lastActivity = Date()
    }

    private func touch() {
        lastActivity = Date()
    }

    private func addUploadBytes(_ count: Int64) {
        receivedUploadBytes += count
        lastActivity = Date()
    }

    private func planUpload(bytes: Int64, count: Int) {
        plannedUploadBytes += bytes
        eventContinuation.yield(.uploadPlanned(count: count, bytes: bytes))
    }

    private func addReceived(_ item: ReceivedItem) {
        receivedItems.append(item)
        eventContinuation.yield(.fileReceived(item))
    }

    private func finishUploadBatch() {
        let batch = Array(receivedItems.dropFirst(reportedItemCount))
        reportedItemCount = receivedItems.count
        eventContinuation.yield(.uploadFinished(batch))
    }

    private func photoTransferRequiresPremium() {
        eventContinuation.yield(.photoTransferRequiresPremium)
    }

    private nonisolated func sendPhotoPremiumRequired(_ io: ConnectionIO) async throws {
        await photoTransferRequiresPremium()
        try await sendJSON(io, status: 402, [
            "error": "photo_transfer_requires_premium",
            "message": "A Premium subscription is required to transfer photos.",
        ])
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        guard !isStopped else {
            connection.cancel()
            return
        }
        let io = ConnectionIO(connection, queue: queue)
        let identifier = ObjectIdentifier(io)
        connections[identifier] = io
        lastActivity = Date()
        Task.detached { [weak self] in
            guard let self else {
                io.abort()
                return
            }
            await self.serve(io)
            await self.connectionFinished(identifier)
        }
    }

    private func connectionFinished(_ identifier: ObjectIdentifier) {
        connections[identifier] = nil
    }

    private func startIdleTimer() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self else { return }
                await self.checkIdle()
            }
        }
    }

    private func checkIdle() {
        guard !isStopped, activeTransfers == 0 else { return }
        if Date().timeIntervalSince(lastActivity) > configuration.idleTimeout {
            stop(reason: .idle)
        }
    }

    // MARK: - Request handling (runs off the actor)

    private nonisolated func serve(_ io: ConnectionIO) async {
        guard let ip = io.remoteIP, NetworkInterfaces.isLocalAddress(ip) else {
            io.abort()
            return
        }
        do {
            try await io.start(timeout: 10)
            let (request, bodyPrefix) = try await readHead(io)
            await touch()
            try await route(request, bodyPrefix: bodyPrefix, io: io, ip: ip)
        } catch {
            if case HTTPParseError.headTooLarge = error {
                try? await sendText(io, status: 400, text: "Bad Request")
            }
        }
        io.close()
    }

    private nonisolated func readHead(_ io: ConnectionIO) async throws -> (HTTPRequest, Data) {
        try await withTransportDeadline(seconds: 20, onTimeout: { io.abort() }) {
            var parser = HTTPRequestParser()
            while true {
                guard let chunk = try await io.receive(maximum: 64 * 1024) else {
                    throw ConnectionIOError.closed
                }
                if let request = try parser.append(chunk) {
                    return (request, parser.bodyPrefix)
                }
            }
        }
    }

    private nonisolated func route(_ request: HTTPRequest, bodyPrefix: Data, io: ConnectionIO, ip: String) async throws {
        let segments = request.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let isRead = request.method == "GET" || request.method == "HEAD"
        guard let first = segments.first else {
            guard isRead else { return try await sendText(io, status: 405, text: "Method Not Allowed") }
            return try await sendPage(io, request: request, config: ["mode": "code", "base": "", "deviceName": configuration.deviceName])
        }
        switch first {
        case "c" where isRead && segments.count == 1:
            try await handleCode(request, io: io, ip: ip)
        case "assets" where isRead && segments.count == 2:
            try await sendAsset(named: segments[1], io: io)
        case "s" where segments.count >= 2:
            guard TransferSecrets.constantTimeEquals(segments[1], token) else {
                return try await sendText(io, status: 404, text: "Not Found")
            }
            if await stopped {
                return try await sendJSON(io, status: 410, ["error": "stopped"])
            }
            try await routeSession(Array(segments.dropFirst(2)), request: request, bodyPrefix: bodyPrefix, io: io, ip: ip)
        default:
            try await sendText(io, status: 404, text: "Not Found")
        }
    }

    private nonisolated func routeSession(
        _ rest: [String],
        request: HTTPRequest,
        bodyPrefix: Data,
        io: ConnectionIO,
        ip: String
    ) async throws {
        let isRead = request.method == "GET" || request.method == "HEAD"
        let mode = configuration.mode
        if rest.isEmpty {
            guard isRead else { return try await sendText(io, status: 405, text: "Method Not Allowed") }
            _ = await registerClient(ip)
            let config: [String: Any] = [
                "mode": mode.rawValue,
                "base": "/s/\(token)",
                "deviceName": configuration.deviceName,
            ]
            return try await sendPage(io, request: request, config: config)
        }
        if rest == ["api", "status"] {
            let state = await registerClient(ip)
            return try await sendJSON(io, status: 200, [
                "state": state.rawValue,
                "mode": mode.rawValue,
                "deviceName": configuration.deviceName,
            ])
        }
        let state = await registerClient(ip)
        guard state == .approved else {
            return try await sendJSON(io, status: 403, ["error": "not_approved", "state": state.rawValue])
        }
        switch (mode, rest.first, request.method) {
        case (.download, "api", _) where rest == ["api", "manifest"] && isRead:
            try await sendJSON(io, status: 200, manifestJSON())
        case (.download, "file", _) where rest.count >= 2 && isRead:
            try await sendFile(indexText: rest[1], request: request, io: io)
        case (.download, "zip", _) where rest.count == 2 && isRead:
            try await sendZip(name: rest[1], request: request, io: io)
        case (.upload, "api", "POST") where rest == ["api", "upload-plan"]:
            try await handleUploadPlan(request: request, bodyPrefix: bodyPrefix, io: io)
        case (.upload, "api", "POST") where rest == ["api", "upload"]:
            try await handleUpload(request: request, bodyPrefix: bodyPrefix, io: io)
        case (.upload, "api", "POST") where rest == ["api", "upload-finish"]:
            await finishUploadBatch()
            try await sendJSON(io, status: 200, ["ok": true])
        default:
            try await sendText(io, status: 404, text: "Not Found")
        }
    }

    // MARK: Pages

    private nonisolated func handleCode(_ request: HTTPRequest, io: ConnectionIO, ip: String) async throws {
        let candidate = (request.query["code"] ?? "").filter(\.isNumber)
        switch await checkCode(candidate, from: ip) {
        case .accepted:
            var head = HTTPResponseHead(status: 302)
            head.setHeader("Location", "/s/\(token)")
            head.setHeader("Content-Length", "0")
            head.setHeader("Cache-Control", "no-store")
            try await io.send(head.serialized())
        case .wrong:
            try await sendPage(io, request: request, config: [
                "mode": "code", "base": "", "deviceName": configuration.deviceName, "error": "wrong_code",
            ])
        case .locked:
            try await sendPage(io, request: request, config: [
                "mode": "code", "base": "", "deviceName": configuration.deviceName, "error": "locked",
            ])
        }
    }

    private nonisolated func sendPage(_ io: ConnectionIO, request: HTTPRequest, config: [String: Any]) async throws {
        let header = request.header("Accept-Language") ?? Locale.preferredLanguages.first
        let language = WebReceiverResources.negotiateLanguage(acceptLanguage: header)
        let body = WebReceiverResources.renderPage(language: language, config: config)
        var head = HTTPResponseHead.data(contentType: "text/html; charset=utf-8", length: body.count)
        head.setHeader("Content-Language", language)
        head.setHeader("Referrer-Policy", "no-referrer")
        head.setHeader("X-Frame-Options", "DENY")
        try await io.send(head.serialized() + (request.method == "HEAD" ? Data() : body))
    }

    private nonisolated func sendAsset(named name: String, io: ConnectionIO) async throws {
        let data: Data?
        if name == "logo.png" {
            data = configuration.logoPNG
        } else {
            data = WebReceiverResources.asset(named: name)
        }
        guard let data else {
            return try await sendText(io, status: 404, text: "Not Found")
        }
        var head = HTTPResponseHead.data(contentType: HTTPResponseHead.contentType(forFilename: name), length: data.count)
        head.setHeader("Cache-Control", "max-age=600")
        try await io.send(head.serialized() + data)
    }

    private nonisolated func sendText(_ io: ConnectionIO, status: Int, text: String) async throws {
        let body = Data(text.utf8)
        let head = HTTPResponseHead.data(status: status, contentType: "text/plain; charset=utf-8", length: body.count)
        try await io.send(head.serialized() + body)
    }

    private nonisolated func sendJSON(_ io: ConnectionIO, status: Int, _ object: [String: Any]) async throws {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        let head = HTTPResponseHead.data(status: status, contentType: "application/json; charset=utf-8", length: body.count)
        try await io.send(head.serialized() + body)
    }

    // MARK: Download mode

    /// Manifest for the Android page: categories, counts, sizes and links.
    nonisolated func manifestJSON() -> [String: Any] {
        let base = "/s/\(token)"
        var categories: [[String: Any]] = []
        var totalBytes: Int64 = 0
        for category in DataCategory.allCases {
            let indexed = entries.enumerated().filter { $0.element.category == category }
            guard !indexed.isEmpty else { continue }
            var bytes: Int64 = 0
            var files: [[String: Any]] = []
            for (index, entry) in indexed {
                let name = WebReceiverServer.fileName(of: entry)
                bytes += entry.byteCount ?? 0
                files.append([
                    "name": name,
                    "path": entry.path,
                    "size": entry.byteCount.map { NSNumber(value: $0) } ?? NSNull(),
                    "url": "\(base)/file/\(index)/\(HTTPResponseHead.rfc5987Encode(name))",
                ])
            }
            totalBytes += bytes
            categories.append([
                "id": category.rawValue,
                "count": indexed.count,
                "bytes": NSNumber(value: bytes),
                "zipUrl": "\(base)/zip/\(category.rawValue)",
                "files": files,
            ])
        }
        return [
            "deviceName": configuration.deviceName,
            "totalCount": entries.count,
            "totalBytes": NSNumber(value: totalBytes),
            "allZipUrl": "\(base)/zip/all",
            "categories": categories,
        ]
    }

    nonisolated static func fileName(of entry: TransferEntry) -> String {
        let name = (entry.path as NSString).lastPathComponent
        return name.isEmpty ? entry.id : name
    }

    private struct StreamLimitReached: Error {}

    private nonisolated func sendFile(indexText: String, request: HTTPRequest, io: ConnectionIO) async throws {
        guard let content, let index = Int(indexText), entries.indices.contains(index) else {
            return try await sendText(io, status: 404, text: "Not Found")
        }
        let entry = entries[index]
        if PhotoTransferPolicy.isPhoto(category: entry.category, path: entry.path),
           !(await configuration.allowsPhotoTransfer()) {
            return try await sendPhotoPremiumRequired(io)
        }
        let name = WebReceiverServer.fileName(of: entry)
        let size = entry.byteCount
        let decision: RangeDecision = size.map { RangeDecision.decide(rangeHeader: request.header("Range"), size: $0) } ?? .full
        let head = HTTPResponseHead.download(
            filename: name,
            contentType: HTTPResponseHead.contentType(forFilename: name),
            size: size,
            decision: decision
        )
        try await io.send(head.serialized())
        guard request.method != "HEAD" else { return }
        let start: Int64
        let limit: Int64?
        switch decision {
        case .unsatisfiable:
            return
        case .partial(let range):
            start = range.lowerBound
            limit = range.upperBound - range.lowerBound + 1
        case .full:
            start = 0
            limit = size
        }
        await transferStarted()
        let sent = OSAllocatedUnfairLock<Int64>(initialState: 0)
        do {
            try await content.read(entry, offset: start) { [self] chunk in
                var data = chunk
                let already = sent.withLock { $0 }
                if let limit {
                    let remaining = limit - already
                    if remaining <= 0 {
                        throw StreamLimitReached()
                    }
                    if Int64(data.count) > remaining {
                        data = data.prefix(Int(remaining))
                    }
                }
                try await io.send(data)
                let count = Int64(data.count)
                let total = sent.withLock { value -> Int64 in
                    value += count
                    return value
                }
                await self.recordDelivered(index: index, upTo: start + total)
                if let limit, total >= limit {
                    throw StreamLimitReached()
                }
            }
        } catch is StreamLimitReached {
            // Range or declared size fully served.
        } catch {
            await transferEnded()
            await recordFailure(ImportFailure(category: entry.category, path: entry.path, reason: error.localizedDescription))
            throw error
        }
        let total = sent.withLock { $0 }
        if let size, start + total >= size {
            await markCompleted(index: index)
        } else if size == nil, start == 0 {
            await markCompleted(index: index)
        }
        await transferEnded()
    }

    private nonisolated func sendZip(name: String, request: HTTPRequest, io: ConnectionIO) async throws {
        guard let content else { return try await sendText(io, status: 404, text: "Not Found") }
        let selected: [(Int, TransferEntry)]
        let archiveName: String
        if name == "all" {
            selected = Array(entries.enumerated())
            archiveName = "SwiftTransfer.zip"
        } else if let category = DataCategory(rawValue: name) {
            selected = entries.enumerated().filter { $0.element.category == category }
            archiveName = "SwiftTransfer_\(category.folderName).zip"
        } else {
            return try await sendText(io, status: 404, text: "Not Found")
        }
        guard !selected.isEmpty else { return try await sendText(io, status: 404, text: "Not Found") }
        if PhotoTransferPolicy.containsPhotos(in: selected.map(\.1)),
           !(await configuration.allowsPhotoTransfer()) {
            return try await sendPhotoPremiumRequired(io)
        }
        var head = HTTPResponseHead(status: 200)
        head.setHeader("Content-Type", "application/zip")
        head.setHeader("Content-Disposition", HTTPResponseHead.contentDisposition(filename: archiveName))
        head.setHeader("Cache-Control", "no-store")
        head.setHeader("X-Content-Type-Options", "nosniff")
        try await io.send(head.serialized())
        guard request.method != "HEAD" else { return }
        await transferStarted()
        let writer = ZipStreamWriter(sink: { data in try await io.send(data) })
        do {
            for (index, entry) in selected {
                try await writer.beginEntry(path: entry.path, modificationDate: entry.modificationDate, expectedSize: entry.byteCount)
                let written = OSAllocatedUnfairLock<Int64>(initialState: 0)
                do {
                    try await content.read(entry, offset: 0) { [self] chunk in
                        try await writer.write(chunk)
                        let total = written.withLock { value -> Int64 in
                            value += Int64(chunk.count)
                            return value
                        }
                        await self.recordDelivered(index: index, upTo: total)
                    }
                    await markCompleted(index: index)
                } catch let error as NWError {
                    throw error
                } catch {
                    // A single unreadable item must not break the archive: close it as-is and report.
                    await recordFailure(ImportFailure(category: entry.category, path: entry.path, reason: error.localizedDescription))
                }
                try await writer.endEntry()
            }
            try await writer.finish()
        } catch {
            await transferEnded()
            throw error
        }
        await transferEnded()
    }

    // MARK: Upload mode

    private struct PhotoPremiumRequired: Error {}
    private struct IncompleteUpload: Error {}

    private nonisolated func readBody(_ io: ConnectionIO, prefix: Data, length: Int64) async throws -> Data {
        var body = prefix
        while Int64(body.count) < length {
            guard let chunk = try await withTransportDeadline(seconds: 30, onTimeout: { io.abort() }, operation: {
                try await io.receive(maximum: 64 * 1024)
            }) else { throw ConnectionIOError.closed }
            body.append(chunk)
        }
        return body.prefix(Int(length))
    }

    private nonisolated func handleUploadPlan(request: HTTPRequest, bodyPrefix: Data, io: ConnectionIO) async throws {
        let length = request.contentLength ?? Int64(bodyPrefix.count)
        guard length <= 64 * 1024 else { return try await sendJSON(io, status: 413, ["error": "too_large"]) }
        let body = try await readBody(io, prefix: bodyPrefix, length: length)
        let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        let bytes = (object["bytes"] as? NSNumber)?.int64Value ?? 0
        let count = (object["count"] as? NSNumber)?.intValue ?? 0
        let directory = uploadDirectory ?? FileManager.default.temporaryDirectory
        let free = TransferDiskSpace.availableCapacity(at: directory)
        guard TransferDiskSpace.hasRoom(for: bytes, at: directory) else {
            return try await sendJSON(io, status: 507, [
                "error": "insufficient_space",
                "freeBytes": NSNumber(value: max(0, (free ?? 0) - TransferDiskSpace.reserve)),
            ])
        }
        await planUpload(bytes: bytes, count: count)
        try await sendJSON(io, status: 200, [
            "ok": true,
            "freeBytes": NSNumber(value: max(0, (free ?? 0) - TransferDiskSpace.reserve)),
        ])
    }

    private nonisolated func handleUpload(request: HTTPRequest, bodyPrefix: Data, io: ConnectionIO) async throws {
        guard let directory = uploadDirectory else { return try await sendText(io, status: 404, text: "Not Found") }
        guard let length = request.contentLength else {
            return try await sendJSON(io, status: 411, ["error": "length_required"])
        }
        guard TransferDiskSpace.hasRoom(for: length, at: directory) else {
            let free = TransferDiskSpace.availableCapacity(at: directory) ?? 0
            return try await sendJSON(io, status: 507, [
                "error": "insufficient_space",
                "freeBytes": NSNumber(value: max(0, free - TransferDiskSpace.reserve)),
            ])
        }
        guard let contentType = request.header("Content-Type"),
              var parser = try? MultipartParser(contentType: contentType)
        else {
            return try await sendJSON(io, status: 400, ["error": "expected_multipart"])
        }
        await transferStarted()
        let sink = UploadFileSink(directory: directory)
        var remaining = length
        var pending = bodyPrefix
        do {
            while true {
                if !pending.isEmpty {
                    let slice = remaining < Int64(pending.count) ? pending.prefix(Int(remaining)) : pending
                    remaining -= Int64(slice.count)
                    await addUploadBytes(Int64(slice.count))
                    for event in try parser.feed(Data(slice)) {
                        if case .partBegin(let info) = event {
                            let filename = info.filename ?? ""
                            let storedName = TransferDiskSpace.sanitizedFileName(filename)
                            let isPhoto = PhotoTransferPolicy.isPhoto(category: nil, path: filename, mimeType: info.contentType)
                                || PhotoTransferPolicy.isPhoto(category: nil, path: storedName)
                            if isPhoto, !(await configuration.allowsPhotoTransfer()) {
                                // The sink has not opened this part or consumed any of its bytes.
                                throw PhotoPremiumRequired()
                            }
                        }
                        if let item = try sink.handle(event) {
                            await addReceived(item)
                        }
                    }
                    pending = Data()
                }
                if remaining <= 0 || parser.isFinished {
                    break
                }
                guard let chunk = try await withTransportDeadline(seconds: 60, onTimeout: { io.abort() }, operation: {
                    try await io.receive(maximum: 256 * 1024)
                }) else { throw ConnectionIOError.closed }
                pending = chunk
            }
            guard parser.isFinished else { throw IncompleteUpload() }
        } catch {
            let partial = sink.abort()
            await addUploadBytes(-partial)
            await transferEnded()
            if error is PhotoPremiumRequired {
                return try await sendPhotoPremiumRequired(io)
            }
            if error is IncompleteUpload {
                return try await sendJSON(io, status: 400, ["error": "incomplete_upload"])
            }
            throw error
        }
        _ = sink.abort()
        await transferEnded()
        try await sendJSON(io, status: 200, ["ok": true, "received": sink.completedCount])
    }

    // MARK: Errors

    nonisolated static func isPolicyDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error {
            return code == -65570
        }
        return false
    }

    nonisolated static func map(_ error: NWError) -> WebReceiverError {
        isPolicyDenied(error) ? .localNetworkDenied : .listenerFailed(error.localizedDescription)
    }
}

/// Writes multipart file parts to disk as they stream in. Used by one connection task only.
private final class UploadFileSink {
    private let directory: URL
    private var handle: FileHandle?
    private var currentURL: URL?
    private var currentName = ""
    private var currentBytes: Int64 = 0
    private(set) var completedCount = 0

    init(directory: URL) {
        self.directory = directory
    }

    /// Returns a finished item when a file part ends.
    func handle(_ event: MultipartEvent) throws -> ReceivedItem? {
        switch event {
        case .partBegin(let info):
            guard let filename = info.filename, !filename.isEmpty else { return nil }
            let name = TransferDiskSpace.sanitizedFileName(filename)
            let url = TransferDiskSpace.uniqueURL(for: name, in: directory)
            // Track the path before opening so failures also remove a newly created partial file.
            currentURL = url
            currentBytes = 0
            FileManager.default.createFile(
                atPath: url.path,
                contents: nil,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            handle = try FileHandle(forWritingTo: url)
            currentName = url.lastPathComponent
            return nil
        case .partData(let data):
            guard let handle else { return nil }
            try handle.write(contentsOf: data)
            currentBytes += Int64(data.count)
            return nil
        case .partEnd:
            guard let handle, let url = currentURL else { return nil }
            try handle.close()
            self.handle = nil
            currentURL = nil
            completedCount += 1
            return ReceivedItem(category: nil, fileURL: url, path: currentName)
        case .finished:
            return nil
        }
    }

    /// Removes a partially written file; returns its byte count.
    func abort() -> Int64 {
        guard let url = currentURL else { return 0 }
        try? handle?.close()
        try? FileManager.default.removeItem(at: url)
        self.handle = nil
        currentURL = nil
        return currentBytes
    }
}
