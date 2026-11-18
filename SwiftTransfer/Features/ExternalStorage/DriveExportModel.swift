import Foundation
import Observation
import os

/// Flow "Save to an external drive" (TZ §4.8): folder → data → writing with verification → result.
@MainActor
@Observable
final class DriveExportModel {
    enum Step: Equatable {
        case chooseFolder
        case selectData
        case preparing
        case writing
        case done
        case failed(String)
    }

    /// FAT32 cannot store files over 4 GB; the user decides whether to skip them.
    struct FAT32Warning: Identifiable {
        let id = UUID()
        let oversized: [TransferEntry]
    }

    private static let logger = Logger(subsystem: "SwiftTransfer", category: "DriveExport")

    var step: Step = .chooseFolder
    var premiumAccess: PremiumAccess
    var selection = TransferSelection()
    private(set) var destination: URL?
    private(set) var progress = BackupProgress()
    private(set) var preparationProgress = 0.0
    private(set) var result: BackupResult?
    private(set) var startedAt: Date?
    var fat32Warning: FAT32Warning?

    private var content: ExportedContent?
    private var task: Task<Void, Never>?
    /// Called once with a history record when the flow finishes (success, partial or failure).
    var onFinish: ((TransferRecord) -> Void)?

    init(access: PremiumAccess = PremiumAccess()) {
        premiumAccess = access
    }

    var destinationName: String {
        destination?.lastPathComponent ?? ""
    }

    var isWorking: Bool {
        step == .preparing || step == .writing
    }

    func folderPicked(_ url: URL) {
        destination = url
        step = .selectData
    }

    func start() {
        guard premiumAccess.authorizePhotos(selection) else { return }
        guard let destination else {
            step = .chooseFolder
            return
        }
        task?.cancel()
        step = .preparing
        preparationProgress = 0
        startedAt = .now
        let selection = selection
        let onPreparation: @Sendable (Double) -> Void = { [weak self] value in
            Task { @MainActor in
                self?.preparationProgress = value
            }
        }
        task = Task { [weak self] in
            do {
                let content = try await ExportService().prepareContent(for: selection, progress: onPreparation)
                guard let self else { return }
                self.content = content
                let preflight = await Task.detached {
                    BackupPackager.preflight(entries: content.entries, destination: destination)
                }.value
                if !preflight.hasEnoughSpace {
                    let error = BackupError.insufficientSpace(
                        required: preflight.requiredBytes,
                        available: preflight.volume.availableBytes ?? 0
                    )
                    self.fail(error.localizedDescription)
                    return
                }
                if !preflight.oversizedEntries.isEmpty {
                    self.fat32Warning = FAT32Warning(oversized: preflight.oversizedEntries)
                    return
                }
                self.write(skipping: [])
            } catch is CancellationError {
                self?.step = .selectData
            } catch {
                self?.fail(error.localizedDescription)
            }
        }
    }

    /// Continues after the FAT32 warning, skipping files larger than 4 GB.
    func continueSkippingOversized() {
        let skipped = Set(fat32Warning?.oversized.map(\.id) ?? [])
        fat32Warning = nil
        write(skipping: skipped)
    }

    func cancelAfterWarning() {
        fat32Warning = nil
        content = nil
        step = .selectData
    }

    func cancel() {
        task?.cancel()
    }

    func reset() {
        task?.cancel()
        content = nil
        result = nil
        progress = BackupProgress()
        step = destination == nil ? .chooseFolder : .selectData
    }

    private func write(skipping skipped: Set<String>) {
        guard let content, let destination else { return }
        // Preparation and the FAT32 prompt can suspend long enough for entitlement to change.
        guard premiumAccess.authorizePhotos(selection),
              !PhotoTransferPolicy.containsPhotos(in: content.entries) || premiumAccess.authorize(.photos)
        else {
            step = .selectData
            return
        }
        step = .writing
        progress = BackupProgress(totalFiles: content.entries.count)
        let onProgress: @Sendable (BackupProgress) -> Void = { [weak self] update in
            Task { @MainActor in
                self?.progress = update
            }
        }
        task = Task { [weak self] in
            guard let self else { return }
            guard self.premiumAccess.authorizePhotos(self.selection),
                  !PhotoTransferPolicy.containsPhotos(in: content.entries) || self.premiumAccess.authorize(.photos)
            else {
                self.step = .selectData
                return
            }
            do {
                let result = try await BackupPackager().writePackage(
                    content: content,
                    to: destination,
                    skippingEntryIDs: skipped,
                    progress: onProgress
                )
                self.finish(result)
            } catch is CancellationError {
                self.fail(String(localized: "Saving was cancelled. The unfinished package on the drive is marked as incomplete."))
            } catch {
                self.fail(error.localizedDescription)
            }
        }
    }

    private func finish(_ result: BackupResult) {
        self.result = result
        let itemCounts = content?.itemCounts ?? [:]
        content = nil
        step = .done
        let issues = result.skipped.map { "\($0.path): \($0.reason)" }
            + result.verificationFailures.map { String(localized: "\($0): verification failed") }
        let status: TransferStatus = issues.isEmpty ? .completed : .partial
        record(status: status, issues: issues, bytes: result.manifest.entries.reduce(0) { $0 + $1.size }, counts: Self.counts(in: result.manifest, itemCounts: itemCounts))
    }

    private func fail(_ message: String) {
        Self.logger.error("Drive export failed: \(message, privacy: .public)")
        content = nil
        step = .failed(message)
        record(status: .failed, issues: [message], bytes: progress.completedBytes, counts: [:])
    }

    private func record(status: TransferStatus, issues: [String], bytes: Int64, counts: [DataCategory: Int]) {
        let record = TransferRecord(
            role: .send,
            method: .externalStorage,
            peerName: destinationName,
            categoryCounts: counts,
            totalBytes: bytes,
            duration: Date().timeIntervalSince(startedAt ?? .now),
            status: status,
            errorSummaries: Array(issues.prefix(50))
        )
        onFinish?(record)
    }

    private static func counts(in manifest: BackupManifest, itemCounts: [DataCategory: Int]) -> [DataCategory: Int] {
        var counts: [DataCategory: Int] = [:]
        for entry in manifest.entries {
            counts[entry.category, default: 0] += 1
        }
        // Generated files hold many items: use the item counts for them.
        for (category, count) in itemCounts where [.contacts, .calendar, .reminders].contains(category) {
            counts[category] = count
        }
        return counts
    }
}
