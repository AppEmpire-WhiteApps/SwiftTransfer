import Foundation
import Observation

/// Flow "Restore from a drive" (TZ §4.8): package folder → contents → import with progress → result.
@MainActor
@Observable
final class DriveRestoreModel {
    enum Step: Equatable {
        case chooseFolder
        case review
        case importing
        case done
        case failed(String)
    }

    var step: Step = .chooseFolder
    var premiumAccess: PremiumAccess
    var policy: DuplicatePolicy = .skip
    private(set) var packageURL: URL?
    private(set) var items: [ReceivedItem] = []
    private(set) var manifest: BackupManifest?
    private(set) var done = 0
    private(set) var total = 0
    private(set) var report: ImportReport?
    /// Called once with a history record when the import finishes.
    var onFinish: ((TransferRecord) -> Void)?

    private var scopedURL: URL?
    private var isAccessing = false
    private var task: Task<Void, Never>?

    init(access: PremiumAccess = PremiumAccess()) {
        premiumAccess = access
    }

    var progress: Double {
        total > 0 ? Double(done) / Double(total) : 0
    }

    var packageName: String {
        packageURL?.lastPathComponent ?? ""
    }

    /// Files per category in the package (generated files count as one file each).
    var fileCounts: [(DataCategory, Int)] {
        var counts: [DataCategory: Int] = [:]
        for item in items {
            counts[ImportService.detectCategory(for: item), default: 0] += 1
        }
        return DataCategory.allCases.compactMap { category in
            counts[category].map { (category, $0) }
        }
    }

    var totalBytes: Int64 {
        if let manifest {
            return manifest.entries.reduce(0) { $0 + $1.size }
        }
        return items.reduce(0) { $0 + ReceivedFilesStore.fileSize($1.fileURL) }
    }

    var isIncomplete: Bool {
        manifest?.complete == false
    }

    func folderPicked(_ url: URL) {
        stopAccess()
        scopedURL = url
        isAccessing = url.startAccessingSecurityScopedResource()
        do {
            let package = try BackupPackager.receivedItems(inPackage: url)
            guard !package.items.isEmpty else {
                throw BackupError.notAPackage
            }
            packageURL = url
            items = package.items
            manifest = package.manifest
            step = .review
        } catch {
            stopAccess()
            step = .failed(error.localizedDescription)
        }
    }

    func startImport() {
        guard !items.isEmpty else { return }
        guard premiumAccess.authorizePhotoItems(items) else { return }
        step = .importing
        done = 0
        total = items.count
        let items = items
        let policy = policy
        let started = Date()
        let bytes = totalBytes
        let onProgress: @Sendable (Int, Int) -> Void = { [weak self] done, total in
            Task { @MainActor in
                self?.done = done
                self?.total = total
            }
        }
        task = Task { [weak self] in
            // Recheck when the scheduled task actually starts, before the importer writes anything.
            guard let self else { return }
            guard self.premiumAccess.authorizePhotoItems(items) else {
                self.step = .review
                return
            }
            let report = await ImportService().importItems(items, policy: policy, progress: onProgress)
            self.finish(report, started: started, bytes: bytes)
        }
    }

    func reset() {
        task?.cancel()
        stopAccess()
        items = []
        manifest = nil
        packageURL = nil
        report = nil
        step = .chooseFolder
    }

    private func finish(_ report: ImportReport, started: Date, bytes: Int64) {
        self.report = report
        done = total
        step = .done
        stopAccess()
        let importedTotal = report.imported.values.reduce(0, +)
        let status: TransferStatus
        if report.failures.isEmpty {
            status = .completed
        } else {
            status = importedTotal > 0 ? .partial : .failed
        }
        let record = TransferRecord(
            role: .receive,
            method: .storageRestore,
            peerName: packageName,
            categoryCounts: report.imported,
            totalBytes: bytes,
            duration: Date().timeIntervalSince(started),
            status: status,
            errorSummaries: report.failures.prefix(50).map { "\($0.path): \($0.reason)" },
            created: report.created
        )
        onFinish?(record)
    }

    private func stopAccess() {
        if isAccessing {
            scopedURL?.stopAccessingSecurityScopedResource()
        }
        isAccessing = false
        scopedURL = nil
    }
}
