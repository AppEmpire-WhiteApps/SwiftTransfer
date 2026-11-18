import Foundation
import Observation
import os
import UIKit

/// State machine for iPhone → Android downloads and Android → iPhone uploads.
/// Legacy P2P implementation remains for compatibility but cannot be launched by this flow.
@MainActor
@Observable
final class TransferFlowModel {
    enum Phase: Equatable {
        case idle
        case preparing
        case waiting
        case transferring
        case importing
        case finished
    }

    /// Seconds to wait for the other device before showing the connection error (TZ §4.2.5).
    static let connectionTimeout: TimeInterval = 60
    /// The web server stops when the app stays in the background longer than this (TZ §4.2.2).
    static let backgroundStopDelay: TimeInterval = 180

    let start: TransferFlowStart
    var premiumAccess = PremiumAccess()
    private(set) var rootRoute: TransferRoute
    var path: [TransferRoute] = []
    private(set) var role: TransferRole
    private(set) var method: TransferMethod?
    var selection = TransferSelection()
    private(set) var phase: Phase = .idle

    // Web receiver
    private(set) var webMode: WebReceiverMode?
    private(set) var webEndpoint: WebReceiverEndpoint?
    private(set) var pendingApprovals: [String] = []

    // P2P
    let browser = PeerBrowser()
    private(set) var peerQRContent: String?
    private(set) var peerCode: String?
    private(set) var peerName = ""
    private(set) var incomingManifest: ManifestMessage?
    private(set) var isConnecting = false
    var connectMessage: String?
    var duplicatePolicy: DuplicatePolicy

    // Progress and result
    private(set) var progress = TransferProgressState()
    private(set) var outcome: TransferOutcome?
    private(set) var failure: TransferFailure?
    var preparationError: String?
    private(set) var isRetrying = false

    /// Called once per finished transfer (saves a `TransferRecord`).
    @ObservationIgnored var onFinish: ((TransferOutcome) -> Void)?
    @ObservationIgnored var activity: AppActivityContext?

    @ObservationIgnored private let log = Logger(subsystem: "SwiftTransfer", category: "TransferFlow")
    @ObservationIgnored private var webServer: WebReceiverServer?
    @ObservationIgnored private var peerSender: PeerSenderSession?
    @ObservationIgnored private var peerReceiver: PeerReceiverSession?
    @ObservationIgnored private var peerTarget: PeerTarget?
    @ObservationIgnored private var content: (any TransferContent)?
    @ObservationIgnored private var retryContent: (any TransferContent)?
    @ObservationIgnored private var receivedForRetry: [ReceivedItem] = []
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var connectTask: Task<Void, Never>?
    @ObservationIgnored private var speedMeter = TransferSpeedMeter()
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private var didStart = false

    init(start: TransferFlowStart) {
        let start = start.availableStart
        self.start = start
        let storedPolicy = UserDefaults.standard.string(forKey: SettingsKey.duplicatePolicy)
        self.duplicatePolicy = storedPolicy.flatMap(DuplicatePolicy.init(rawValue:)) ?? .skip
        switch start {
        case .send(let target):
            role = .send
            switch target {
            case .android:
                rootRoute = .selectData(.android)
                method = .webAndroid
            case .iPhone:
                rootRoute = .chooseTarget
                method = nil
            case .storage, nil:
                rootRoute = .chooseTarget
                method = nil
            }
        case .receive(let origin):
            role = .receive
            switch origin {
            case .iPhone:
                rootRoute = .chooseOrigin
                method = nil
            case .android:
                rootRoute = .webConnect
                method = .androidUpload
                webMode = .upload
            case nil:
                rootRoute = .chooseOrigin
                method = nil
            }
        }
    }

    // MARK: - Derived state

    var currentRoute: TransferRoute {
        path.last ?? rootRoute
    }

    /// Defense in depth for stale navigation paths and legacy routes.
    func availableRoute(_ route: TransferRoute) -> TransferRoute {
        switch route {
        case .peerScan, .peerWait, .incoming, .selectData(.iPhone):
            role == .send ? .chooseTarget : .chooseOrigin
        default:
            route
        }
    }

    private var hasRetiredRoute: Bool {
        ([rootRoute] + path).contains { availableRoute($0) != $0 }
    }

    private func returnToChooser() {
        teardown()
        rootRoute = role == .send ? .chooseTarget : .chooseOrigin
        path = []
        method = nil
        webMode = nil
        phase = .idle
        outcome = nil
        failure = nil
        retryContent = nil
        receivedForRetry = []
        isRetrying = false
        updateActivity(state: "choosing")
    }

    /// Closing needs a confirmation while a session is running.
    var needsCloseConfirmation: Bool {
        switch phase {
        case .waiting, .transferring, .importing: true
        case .idle, .preparing, .finished: false
        }
    }

    var canPause: Bool {
        method == .peer && phase == .transferring
    }

    var currentApproval: String? {
        pendingApprovals.first
    }

    var deviceName: String {
        UIDevice.current.name
    }

    static var localDevice: PeerDeviceInfo {
        PeerDeviceInfo(
            name: UIDevice.current.name,
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion
        )
    }

    // MARK: - Entry

    /// Starts the work of the first screen (receivers start listening immediately).
    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        guard !hasRetiredRoute, method != .peer else {
            returnToChooser()
            return
        }
        TransferDiskSpace.removeSessionDirectories(kind: "PeerInbox")
        TransferDiskSpace.removeSessionDirectories(kind: "WebUploads")
        switch rootRoute {
        case .webConnect:
            startWebUpload()
        default:
            updateActivity(state: "choosing")
        }
    }

    func chooseTarget(_ target: TransferTarget) {
        guard role == .send, TransferDirectionPolicy.allows(target: target) else {
            returnToChooser()
            return
        }
        switch target {
        case .android:
            method = .webAndroid
            path.append(.selectData(.android))
        case .iPhone:
            returnToChooser()
        case .storage:
            break
        }
        updateActivity(state: "selecting")
    }

    func chooseOrigin(_ origin: TransferOrigin) {
        guard role == .receive, TransferDirectionPolicy.allows(origin: origin) else {
            returnToChooser()
            return
        }
        switch origin {
        case .iPhone:
            returnToChooser()
        case .android:
            method = .androidUpload
            webMode = .upload
            path.append(.webConnect)
            startWebUpload()
        }
    }

    /// "Continue" on SelectDataView.
    func continueFromSelection(target: TransferTarget) {
        guard role == .send, TransferDirectionPolicy.allows(target: target) else {
            returnToChooser()
            return
        }
        guard phase == .idle || phase == .waiting || phase == .finished else { return }
        switch target {
        case .android:
            startWebDownload()
        case .iPhone:
            returnToChooser()
        case .storage:
            break
        }
    }

    /// Leaving a connect screen with Back stops its session.
    func handlePathChange() {
        guard !hasRetiredRoute, method != .peer else {
            returnToChooser()
            return
        }
        guard phase == .waiting || phase == .idle else { return }
        let routes = Set([rootRoute] + path)
        if webServer != nil, !routes.contains(.webConnect) {
            stopWebServer(reason: .cancelled)
            phase = .idle
        }
        if peerReceiver != nil, !routes.contains(.peerWait), !routes.contains(.incoming) {
            let receiver = peerReceiver
            peerReceiver = nil
            Task { await receiver?.cancel() }
            phase = .idle
        }
        if peerSender != nil, !routes.contains(where: { if case .selectData = $0 { return true } else { return false } }) {
            let sender = peerSender
            peerSender = nil
            Task { await sender?.cancel() }
            phase = .idle
        }
        cancelTimeout()
    }

    // MARK: - Web download (iPhone → Android)

    private func startWebDownload() {
        guard premiumAccess.authorizePhotos(selection, preparedEntries: retryContent?.entries) else { return }
        phase = .preparing
        updateActivity(state: "preparing")
        let selection = self.selection
        let prepared = retryContent
        retryContent = nil
        let task = Task { [weak self] in
            do {
                let content: any TransferContent
                if let prepared {
                    content = prepared
                } else {
                    content = try await TransferContentSource.makeContent(for: selection)
                }
                guard let self else { return }
                if PhotoTransferPolicy.containsPhotos(in: content.entries), !self.premiumAccess.authorize(.photos) {
                    self.phase = .idle
                    return
                }
                guard !content.entries.isEmpty else {
                    self.phase = .idle
                    self.preparationError = TransferFailure.nothingToSend.message
                    return
                }
                self.content = content
                try await self.launchWebServer(mode: .download, content: content)
                if self.currentRoute != .webConnect {
                    self.path.append(.webConnect)
                }
            } catch {
                self?.handleWebStartError(error)
            }
        }
        tasks.append(task)
    }

    // MARK: - Web upload (Android → iPhone)

    private func startWebUpload() {
        phase = .preparing
        let task = Task { [weak self] in
            do {
                try await self?.launchWebServer(mode: .upload, content: nil)
            } catch {
                self?.handleWebStartError(error)
            }
        }
        tasks.append(task)
    }

    private func launchWebServer(mode: WebReceiverMode, content: (any TransferContent)?) async throws {
        stopWebServer(reason: .cancelled)
        var configuration = WebReceiverServer.Configuration(mode: mode, deviceName: deviceName)
        let access = premiumAccess
        configuration.allowsPhotoTransfer = { await access.isPremium }
        configuration.logoPNG = Illustration.appLogoPNGData
        let server = try WebReceiverServer(configuration: configuration, content: content)
        webServer = server
        webMode = mode
        pendingApprovals = []
        let endpoint = try await server.start()
        webEndpoint = endpoint
        phase = .waiting
        updateActivity(state: "connecting")
        startConnectionTimeout()
        let events = Task { [weak self] in
            for await event in server.events {
                self?.handleWebEvent(event, from: server)
            }
        }
        tasks.append(events)
        let refresh = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, self.webServer === server, self.phase == .waiting else { continue }
                if let endpoint = await server.endpoint(), endpoint != self.webEndpoint {
                    self.webEndpoint = endpoint
                }
            }
        }
        tasks.append(refresh)
    }

    private func handleWebStartError(_ error: Error) {
        phase = .idle
        if let error = error as? WebReceiverError, error == .localNetworkDenied {
            show(failure: .localNetworkDenied)
        } else {
            show(failure: .generic(error.localizedDescription))
        }
    }

    private func handleWebEvent(_ event: WebReceiverEvent, from server: WebReceiverServer) {
        guard server === webServer else { return }
        switch event {
        case .photoTransferRequiresPremium:
            _ = premiumAccess.authorize(.photos)
        case .approvalRequested(let client):
            if !pendingApprovals.contains(client) {
                pendingApprovals.append(client)
            }
        case .clientApproved:
            if phase == .waiting {
                beginTransferPhase()
            }
        case .uploadPlanned, .fileReceived:
            if phase == .waiting {
                beginTransferPhase()
            }
        case .uploadFinished(let items):
            guard !items.isEmpty else { return }
            Task { await self.finishWebUpload(stopReason: .finished) }
        case .stopped(let reason):
            switch reason {
            case .idle, .background:
                if webMode == .upload {
                    Task { await self.finishWebUpload(stopReason: reason) }
                } else {
                    Task { await self.finishWebDownload() }
                }
            case .failed(let message):
                if phase != .finished {
                    show(failure: .generic(message))
                }
            case .finished, .cancelled:
                break
            }
        }
    }

    /// Answer to "Device 192.168.x.x wants to receive data. Allow?"
    func answerApproval(allow: Bool) {
        guard let client = pendingApprovals.first, let server = webServer else { return }
        pendingApprovals.removeFirst()
        Task {
            if allow {
                await server.approve(client: client)
            } else {
                await server.deny(client: client)
            }
        }
    }

    /// "Finish" on S6 for web sessions.
    func finishWebSession() {
        Task {
            if webMode == .upload {
                await finishWebUpload(stopReason: .finished)
            } else {
                await finishWebDownload()
            }
        }
    }

    private func finishWebDownload() async {
        guard let server = webServer, phase != .finished else { return }
        await pollOnce()
        let snapshot = await server.progress()
        stopWebServer(reason: .finished)
        let itemsDone = snapshot.categoryItemsDone.values.reduce(0, +)
        let itemsTotal = snapshot.categoryItemsTotal.values.reduce(0, +)
        let status: TransferStatus
        if itemsTotal > 0, itemsDone >= itemsTotal, snapshot.failures.isEmpty {
            status = .completed
        } else if itemsDone > 0 {
            status = .partial
        } else {
            status = .cancelled
        }
        var failures = snapshot.failures
        if status == .partial {
            let done = snapshot.categoryItemsDone
            for category in DataCategory.allCases where (done[category] ?? 0) < (snapshot.categoryItemsTotal[category] ?? 0) {
                let missing = (snapshot.categoryItemsTotal[category] ?? 0) - (done[category] ?? 0)
                failures.append(ImportFailure(
                    category: category,
                    path: category.folderName,
                    reason: String(localized: "\(missing) items were not downloaded")
                ))
            }
        }
        finish(with: TransferOutcome(
            status: status,
            role: .send,
            method: .webAndroid,
            counts: snapshot.categoryItemsDone,
            failures: failures,
            bytes: snapshot.bytesDone,
            duration: elapsed,
            peerName: String(localized: "Android")
        ))
    }

    private func finishWebUpload(stopReason: WebReceiverStopReason) async {
        guard let server = webServer, phase != .finished, phase != .importing else { return }
        let items = await server.uploadedItems()
        let snapshot = await server.progress()
        stopWebServer(reason: stopReason)
        guard !items.isEmpty else {
            finish(with: TransferOutcome(status: .cancelled, role: .receive, method: .androidUpload, duration: elapsed, peerName: String(localized: "Android")))
            return
        }
        await runImport(items: items, bytes: snapshot.bytesDone, method: .androidUpload, transferFailures: snapshot.failures)
    }

    private func stopWebServer(reason: WebReceiverStopReason) {
        guard let server = webServer else { return }
        if reason != .finished || webMode == .download {
            webServer = nil
        }
        Task { await server.stop(reason: reason) }
    }

    // MARK: - P2P receiver

    private func startPeerReceiver() {
        guard TransferDirectionPolicy.allows(method: .peer) else {
            returnToChooser()
            return
        }
        phase = .preparing
        let receiver = PeerReceiverSession(
            configuration: .init(device: Self.localDevice),
            importer: ImportService()
        )
        peerReceiver = receiver
        peerCode = receiver.code
        peerQRContent = try? receiver.qrPayload.encoded()
        let task = Task { [weak self] in
            do {
                try await receiver.start()
                guard let self, self.peerReceiver === receiver else { return }
                self.phase = .waiting
                self.updateActivity(state: "waiting")
                self.startConnectionTimeout()
                for await event in receiver.events {
                    self.handleReceiverEvent(event, from: receiver)
                }
            } catch let error as PeerError {
                self?.phase = .idle
                self?.show(failure: TransferFailure(error))
            } catch {
                self?.phase = .idle
                self?.show(failure: .generic(error.localizedDescription))
            }
        }
        tasks.append(task)
    }

    private func handleReceiverEvent(_ event: PeerReceiverEvent, from receiver: PeerReceiverSession) {
        guard receiver === peerReceiver else { return }
        switch event {
        case .ready:
            break
        case .peerConnected(let hello):
            peerName = hello.deviceName
            cancelTimeout()
        case .incoming(let manifest, let hello):
            peerName = hello.deviceName
            incomingManifest = manifest
            cancelTimeout()
            if currentRoute != .incoming {
                path.append(.incoming)
            }
            updateActivity(state: "confirming", manifest: manifest)
        case .transferStarted:
            beginTransferPhase()
        case .pausedChanged(let paused):
            progress.isPaused = paused
        case .reconnecting:
            progress.isReconnecting = true
        case .reconnected:
            progress.isReconnecting = false
        case .importing:
            phase = .importing
            progress.isImporting = true
            updateActivity(state: "importing")
        case .completed(let report):
            Task { await self.completeReceiver(report: report, receiver: receiver) }
        case .failed(let error):
            if phase != .finished {
                show(failure: TransferFailure(error))
            }
        case .wrongCodeAttempt:
            break
        }
    }

    private func completeReceiver(report: ImportReport, receiver: PeerReceiverSession) async {
        await pollOnce()
        let failedPaths = Set(report.failures.map(\.path))
        receivedForRetry = await receiver.receivedItems(forPaths: failedPaths)
        let status: TransferStatus = report.failures.isEmpty ? .completed : (report.imported.isEmpty && report.savedFiles == 0 ? .failed : .partial)
        finish(with: TransferOutcome(
            status: status,
            role: .receive,
            method: .peer,
            counts: report.imported,
            skippedDuplicates: report.skippedDuplicates,
            savedFiles: report.savedFiles,
            failures: report.failures,
            bytes: progress.bytesDone,
            duration: elapsed,
            peerName: peerName,
            created: report.created
        ))
    }

    /// S4d answer.
    func answerIncoming(accept: Bool) {
        guard TransferDirectionPolicy.allows(method: .peer) else {
            returnToChooser()
            return
        }
        guard let receiver = peerReceiver else { return }
        UserDefaults.standard.set(duplicatePolicy.rawValue, forKey: SettingsKey.duplicatePolicy)
        let policy = duplicatePolicy
        Task {
            if accept {
                if let manifest = incomingManifest, !TransferDiskSpace.hasRoom(for: manifest.totalBytes) {
                    await receiver.decline()
                    show(failure: .insufficientSpace)
                    return
                }
                await receiver.accept(policy: policy)
            } else {
                await receiver.decline()
                peerReceiver = nil
                phase = .finished
                path.removeAll { $0 == .incoming }
                incomingManifest = nil
                restartPeerReceiver()
            }
        }
    }

    private func restartPeerReceiver() {
        phase = .idle
        startPeerReceiver()
    }

    // MARK: - P2P sender

    /// Connects to a receiver from a scanned QR code.
    func connect(qrPayload: PeerQRPayload) {
        guard TransferDirectionPolicy.allows(method: .peer) else {
            returnToChooser()
            return
        }
        guard let target = PeerTarget.qr(qrPayload) else {
            connectMessage = String(localized: "This QR code isn't a supported transfer code.")
            return
        }
        connect(to: target)
    }

    /// Connects to a nearby device with the typed 6-digit code.
    func connect(peer: DiscoveredPeer, code: String) {
        guard TransferDirectionPolicy.allows(method: .peer) else {
            returnToChooser()
            return
        }
        guard let target = PeerTarget.discovered(peer, code: code) else {
            connectMessage = String(localized: "This device can't be reached. Ask its owner to reopen the receive screen.")
            return
        }
        connect(to: target)
    }

    private func connect(to target: PeerTarget) {
        guard TransferDirectionPolicy.allows(method: .peer) else {
            returnToChooser()
            return
        }
        guard !isConnecting else { return }
        isConnecting = true
        connectMessage = nil
        peerTarget = target
        updateActivity(state: "connecting")
        connectTask?.cancel()
        connectTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(Self.connectionTimeout)
            var lastError: PeerError = .timeout
            while Date() < deadline, !Task.isCancelled {
                let sender = PeerSenderSession(target: target, device: Self.localDevice)
                do {
                    let hello = try await sender.connect()
                    guard let self, !Task.isCancelled else {
                        await sender.cancel()
                        return
                    }
                    self.peerSender = sender
                    self.peerName = hello.deviceName
                    self.isConnecting = false
                    self.phase = .waiting
                    self.connectedToReceiver()
                    return
                } catch let error as PeerError {
                    lastError = error
                    switch error {
                    case .timeout, .connectionFailed, .connectionLost:
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        continue
                    default:
                        break
                    }
                } catch {
                    lastError = .connectionFailed(error.localizedDescription)
                }
                break
            }
            guard let self, !Task.isCancelled else { return }
            self.isConnecting = false
            switch lastError {
            case .authenticationFailed:
                self.connectMessage = TransferFailure.authenticationFailed.message
            case .timeout, .connectionFailed, .connectionLost:
                self.show(failure: .connectionTimeout)
            default:
                self.show(failure: TransferFailure(lastError))
            }
        }
    }

    func cancelConnecting() {
        connectTask?.cancel()
        connectTask = nil
        isConnecting = false
    }

    private func connectedToReceiver() {
        if let retryContent {
            self.retryContent = nil
            sendPeer(content: retryContent)
        } else if !path.contains(.selectData(.iPhone)) {
            path.append(.selectData(.iPhone))
            updateActivity(state: "selecting")
        }
    }

    private func startPeerSend() {
        guard TransferDirectionPolicy.allows(method: .peer) else {
            returnToChooser()
            return
        }
        guard peerSender != nil else {
            path.removeAll { $0 == .selectData(.iPhone) }
            return
        }
        phase = .preparing
        let selection = self.selection
        let task = Task { [weak self] in
            do {
                let content = try await TransferContentSource.makeContent(for: selection)
                guard let self else { return }
                guard !content.entries.isEmpty else {
                    self.phase = .waiting
                    self.preparationError = TransferFailure.nothingToSend.message
                    return
                }
                self.sendPeer(content: content)
            } catch {
                self?.phase = .waiting
                self?.preparationError = error.localizedDescription
            }
        }
        tasks.append(task)
    }

    private func sendPeer(content: any TransferContent) {
        guard TransferDirectionPolicy.allows(method: .peer) else {
            returnToChooser()
            return
        }
        guard let sender = peerSender else { return }
        self.content = content
        beginTransferPhase(manifest: ManifestMessage(sessionID: sender.sessionID, entries: content.entries))
        let events = Task { [weak self] in
            for await event in sender.events {
                self?.handleSenderEvent(event)
            }
        }
        tasks.append(events)
        let task = Task { [weak self] in
            let result = await sender.send(content: content)
            await self?.completeSender(result)
        }
        tasks.append(task)
    }

    private func handleSenderEvent(_ event: PeerSenderEvent) {
        switch event {
        case .reconnecting:
            progress.isReconnecting = true
        case .reconnected:
            progress.isReconnecting = false
        case .pausedChanged(let paused):
            progress.isPaused = paused
        case .allSent:
            phase = .importing
            progress.isImporting = true
            updateActivity(state: "importing")
        case .completed, .failed:
            break
        }
    }

    private func completeSender(_ result: Result<PeerSendResult, PeerError>) async {
        guard phase != .finished else { return }
        await pollOnce()
        switch result {
        case .success(let sent):
            var counts: [DataCategory: Int] = [:]
            if let report = sent.report {
                counts = report.imported
                for (category, skipped) in report.skippedDuplicates {
                    counts[category, default: 0] += skipped
                }
            } else {
                counts = progress.categories.reduce(into: [:]) { $0[$1.category] = $1.itemsDone }
            }
            let failures = sent.report?.failures ?? sent.failures
            let status: TransferStatus = failures.isEmpty ? .completed : (sent.sentCount == 0 ? .failed : .partial)
            finish(with: TransferOutcome(
                status: status,
                role: .send,
                method: .peer,
                counts: counts,
                failures: failures,
                bytes: progress.bytesDone,
                duration: elapsed,
                peerName: peerName
            ))
        case .failure(let error):
            if error == .cancelledByPeer, phase == .finished {
                return
            }
            show(failure: TransferFailure(error))
        }
    }

    // MARK: - Transfer phase

    private func beginTransferPhase(manifest: ManifestMessage? = nil) {
        guard phase != .transferring else { return }
        cancelTimeout()
        phase = .transferring
        startedAt = Date()
        speedMeter.reset()
        progress = TransferProgressState()
        if let manifest = manifest ?? incomingManifest {
            progress.categories = manifest.summaries.map {
                CategoryProgress(category: $0.category, itemsTotal: $0.summary.itemCount, bytesTotal: $0.summary.byteCount)
            }
            progress.bytesTotal = manifest.totalBytes
            updateActivity(state: "transferring", manifest: manifest)
        } else {
            updateActivity(state: "transferring")
        }
        path.removeAll { $0 == .failure }
        if currentRoute != .progress {
            path.append(.progress)
        }
        startPolling()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOnce()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func pollOnce() async {
        let now = Date().timeIntervalSinceReferenceDate
        if let server = webServer {
            let snapshot = await server.progress()
            apply(web: snapshot, at: now)
        } else if let sender = peerSender {
            let snapshot = await sender.progress()
            apply(peer: snapshot, at: now)
        } else if let receiver = peerReceiver {
            let snapshot = await receiver.progress()
            apply(peer: snapshot, at: now)
        }
    }

    private func apply(web snapshot: WebTransferProgress, at time: TimeInterval) {
        guard phase == .transferring else { return }
        var state = progress
        state.bytesDone = snapshot.bytesDone
        state.bytesTotal = snapshot.bytesTotal
        state.receivedFiles = snapshot.receivedFiles
        state.categories = DataCategory.allCases.compactMap { category in
            let total = snapshot.categoryItemsTotal[category] ?? 0
            guard total > 0 else { return nil }
            return CategoryProgress(
                category: category,
                itemsDone: snapshot.categoryItemsDone[category] ?? 0,
                itemsTotal: total,
                bytesDone: snapshot.categoryBytesDone[category] ?? 0,
                bytesTotal: snapshot.categoryBytesTotal[category] ?? 0,
                failures: snapshot.failures.filter { $0.category == category }.count
            )
        }
        if webMode == .download {
            let done = snapshot.categoryItemsDone.values.reduce(0, +)
            let total = snapshot.categoryItemsTotal.values.reduce(0, +)
            state.allDelivered = total > 0 && done >= total
        }
        state.bytesPerSecond = speedMeter.add(bytes: snapshot.bytesDone, at: time)
        progress = state
    }

    private func apply(peer snapshot: PeerProgressSnapshot, at time: TimeInterval) {
        var state = progress
        state.bytesDone = snapshot.bytesDone
        state.bytesTotal = snapshot.bytesTotal
        state.isPaused = snapshot.isPaused
        state.isReconnecting = snapshot.isReconnecting
        state.importDone = snapshot.importDone
        state.importTotal = snapshot.importTotal
        state.categories = DataCategory.allCases.compactMap { category in
            let total = snapshot.categoryItemsTotal[category] ?? 0
            guard total > 0 else { return nil }
            return CategoryProgress(
                category: category,
                itemsDone: snapshot.categoryItemsDone[category] ?? 0,
                itemsTotal: total,
                bytesDone: snapshot.categoryBytesDone[category] ?? 0,
                bytesTotal: snapshot.categoryBytesTotal[category] ?? 0,
                failures: snapshot.categoryFailures[category] ?? 0
            )
        }
        state.bytesPerSecond = snapshot.isPaused ? nil : speedMeter.add(bytes: snapshot.bytesDone, at: time)
        progress = state
    }

    func setPaused(_ paused: Bool) {
        progress.isPaused = paused
        if paused {
            speedMeter.reset()
        }
        Task {
            await peerSender?.setPaused(paused)
            await peerReceiver?.setPaused(paused)
        }
    }

    // MARK: - Import (receivers)

    private func runImport(items: [ReceivedItem], bytes: Int64, method: TransferMethod, transferFailures: [ImportFailure]) async {
        guard premiumAccess.authorizePhotoItems(items) else {
            receivedForRetry = items
            let reason = String(localized: "A subscription is required to transfer photos.")
            let failures = items.map { ImportFailure(category: $0.category, path: $0.path, reason: reason) }
            finish(with: TransferOutcome(status: .failed, role: .receive, method: method,
                                         failures: failures, bytes: bytes, duration: elapsed,
                                         peerName: String(localized: "Android")))
            return
        }
        phase = .importing
        progress.isImporting = true
        progress.importDone = 0
        progress.importTotal = items.count
        updateActivity(state: "importing")
        if currentRoute != .progress {
            path.append(.progress)
        }
        let report = await ImportService().importItems(items, policy: duplicatePolicy) { [weak self] done, total in
            Task { @MainActor in
                self?.progress.importDone = done
                self?.progress.importTotal = total
            }
        }
        let failures = report.failures + transferFailures
        let failedPaths = Set(failures.map(\.path))
        receivedForRetry = items.filter { failedPaths.contains($0.path) }
        let imported = report.imported.values.reduce(0, +) + report.savedFiles + report.skippedDuplicates.values.reduce(0, +)
        let status: TransferStatus = failures.isEmpty ? .completed : (imported == 0 ? .failed : .partial)
        finish(with: TransferOutcome(
            status: status,
            role: .receive,
            method: method,
            counts: report.imported,
            skippedDuplicates: report.skippedDuplicates,
            savedFiles: report.savedFiles,
            failures: failures,
            bytes: bytes,
            duration: elapsed,
            peerName: String(localized: "Android"),
            created: report.created
        ))
    }

    // MARK: - Finish, cancel, retry

    private var elapsed: TimeInterval {
        startedAt.map { Date().timeIntervalSince($0) } ?? 0
    }

    private func finish(with outcome: TransferOutcome) {
        guard phase != .finished || isRetrying else { return }
        isRetrying = false
        pollTask?.cancel()
        pollTask = nil
        cancelTimeout()
        endBackgroundTask()
        phase = .finished
        progress.isImporting = false
        self.outcome = outcome
        let lastError = outcome.failures.isEmpty ? nil : "\(outcome.failures.count)_items_failed"
        updateActivity(state: outcome.status.rawValue, error: lastError)
        onFinish?(outcome)
        path.removeAll { $0 == .failure }
        if currentRoute != .result {
            path.append(.result)
        }
    }

    /// User confirmed "Cancel" on S6.
    func cancelTransfer() {
        let partial = progress
        let wasActive = phase == .transferring || phase == .importing
        teardown()
        guard wasActive else { return }
        let counts = partial.categories.reduce(into: [DataCategory: Int]()) { result, item in
            if item.itemsDone > 0 {
                result[item.category] = item.itemsDone
            }
        }
        phase = .transferring
        finish(with: TransferOutcome(
            status: .cancelled,
            role: role,
            method: method ?? .peer,
            counts: counts,
            bytes: partial.bytesDone,
            duration: elapsed,
            peerName: peerName
        ))
    }

    /// Whether "Retry failed" can do something useful for this outcome.
    var canRetryFailed: Bool {
        guard let outcome,
              TransferDirectionPolicy.allows(method: outcome.method),
              !outcome.failures.isEmpty else { return false }
        switch outcome.method {
        case .peer:
            return false
        case .androidUpload:
            return !receivedForRetry.isEmpty
        case .webAndroid:
            return content != nil
        case .externalStorage, .storageRestore:
            return false
        }
    }

    /// S7 "Retry failed".
    func retryFailed() {
        guard let outcome else { return }
        guard TransferDirectionPolicy.allows(method: outcome.method) else {
            returnToChooser()
            return
        }
        let failedPaths = Set(outcome.failures.map(\.path))
        switch (outcome.method, outcome.role) {
        case (.androidUpload, _):
            let items = receivedForRetry
            guard !items.isEmpty else { return }
            isRetrying = true
            Task { await runImport(items: items, bytes: outcome.bytes, method: outcome.method, transferFailures: []) }
        case (.webAndroid, _):
            guard let content else { return }
            let failedCategories = Set(outcome.failures.compactMap(\.category))
            let subset = FilteredTransferContent(base: content, paths: failedPaths)
            retryContent = subset.entries.isEmpty
                ? FilteredTransferContent(base: content, entryIDs: Set(content.entries.filter { failedCategories.contains($0.category) }.map(\.id)))
                : subset
            resetForRetry()
            startWebDownload()
        default:
            break
        }
    }

    private func resetForRetry() {
        outcome = nil
        failure = nil
        phase = .idle
        progress = TransferProgressState()
        peerSender = nil
        path.removeAll { $0 == .result || $0 == .progress }
    }

    /// "Retry" on the error screen.
    func retryAfterFailure() {
        guard !hasRetiredRoute, method != .peer else {
            returnToChooser()
            return
        }
        let current = failure
        failure = nil
        path.removeAll { $0 == .failure }
        switch current {
        case .connectionTimeout where phase == .waiting:
            // The session is still running (S4a/S4c): give it another minute.
            startConnectionTimeout()
        default:
            teardown()
            phase = .idle
            didStart = false
            path.removeAll { $0 == .progress || $0 == .incoming || $0 == .result }
            switch currentRoute {
            case .webConnect:
                if webMode == .upload {
                    startWebUpload()
                } else {
                    path.removeAll { $0 == .webConnect }
                    startWebDownload()
                }
            default:
                break
            }
        }
    }

    private func show(failure: TransferFailure) {
        log.error("Transfer failure: \(failure.code, privacy: .public)")
        self.failure = failure
        pollTask?.cancel()
        pollTask = nil
        endBackgroundTask()
        if phase == .transferring || phase == .importing {
            let partial = progress
            teardown()
            phase = .finished
            let outcome = TransferOutcome(
                status: .failed,
                role: role,
                method: method ?? .peer,
                counts: partial.categories.reduce(into: [:]) { $0[$1.category] = $1.itemsDone },
                failures: [],
                bytes: partial.bytesDone,
                duration: elapsed,
                peerName: peerName
            )
            onFinish?(outcome)
        }
        updateActivity(state: "failed", error: failure.code)
        if currentRoute != .failure {
            path.append(.failure)
        }
    }

    /// Stops every session (Close, Cancel, leaving the flow).
    func teardown() {
        connectTask?.cancel()
        connectTask = nil
        pollTask?.cancel()
        pollTask = nil
        cancelTimeout()
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
        if let server = webServer {
            webServer = nil
            let directory = server.uploadDirectory
            Task {
                await server.stop(reason: .cancelled)
                if let directory, phase != .importing {
                    try? FileManager.default.removeItem(at: directory)
                }
            }
        }
        if let sender = peerSender {
            peerSender = nil
            Task { await sender.cancel() }
        }
        if let receiver = peerReceiver {
            peerReceiver = nil
            Task { await receiver.cancel() }
        }
        browser.stop()
        endBackgroundTask()
        isConnecting = false
        pendingApprovals = []
    }

    /// Called when the flow closes for good.
    func close() {
        let receiver = peerReceiver
        teardown()
        Task { await receiver?.discardInbox() }
        TransferDiskSpace.removeSessionDirectories(kind: "PeerInbox")
        TransferDiskSpace.removeSessionDirectories(kind: "WebUploads")
        activity?.transfer = nil
    }

    // MARK: - Timeouts and background

    private func startConnectionTimeout() {
        cancelTimeout()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.connectionTimeout * 1_000_000_000))
            guard !Task.isCancelled, let self, self.phase == .waiting else { return }
            self.show(failure: .connectionTimeout)
        }
    }

    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    func scenePhaseChanged(isActive: Bool, isBackground: Bool) {
        if isBackground {
            backgroundedAt = Date()
            guard phase == .transferring || phase == .importing || (phase == .waiting && webServer != nil) else { return }
            beginBackgroundTask()
            if phase == .transferring {
                TransferNotifications.schedulePausedReminder()
            }
        } else if isActive {
            TransferNotifications.cancelPausedReminder()
            endBackgroundTask()
            if let since = backgroundedAt, Date().timeIntervalSince(since) > Self.backgroundStopDelay, let server = webServer {
                Task { await server.stop(reason: .background) }
            }
            backgroundedAt = nil
        }
    }

    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SwiftTransfer transfer") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: - Assistant context

    private func updateActivity(state: String, manifest: ManifestMessage? = nil, error: String? = nil) {
        guard let activity else { return }
        var categories = activity.transfer?.categories ?? [:]
        var totalBytes = activity.transfer?.totalBytes ?? 0
        if let manifest {
            categories = Dictionary(uniqueKeysWithValues: manifest.summaries.map { ($0.category.rawValue, $0.summary.itemCount) })
            totalBytes = manifest.totalBytes
        } else if let content, categories.isEmpty {
            for entry in content.entries {
                categories[entry.category.rawValue, default: 0] += 1
                totalBytes += entry.byteCount ?? 0
            }
        }
        activity.transfer = TransferContextInfo(
            direction: role,
            method: method ?? (role == .send ? .webAndroid : .peer),
            categories: categories,
            totalBytes: totalBytes,
            state: state,
            lastError: error
        )
    }

    /// Draft for "Ask the assistant" describing the problem without personal data.
    var assistantDraft: String {
        if let failure {
            return String(localized: "My transfer failed: \(failure.title). \(failure.message) What should I do?")
        }
        if let outcome, !outcome.failures.isEmpty {
            let reasons = Set(outcome.failures.map(\.reason)).prefix(3).joined(separator: "; ")
            return String(localized: "\(outcome.failures.count) items failed to transfer (\(reasons)). How can I fix this?")
        }
        switch currentRoute {
        case .webConnect:
            return String(localized: "The Android phone can't open the transfer page. What should I check?")
        case .peerScan, .peerWait:
            return String(localized: "My two iPhones don't find each other. What should I check?")
        default:
            return String(localized: "I need help with my transfer.")
        }
    }
}
