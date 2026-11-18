import Darwin
import Foundation
import os

/// Progress of writing a package to an external drive.
struct BackupProgress: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        case writing
        case verifying
    }

    var phase: Phase = .writing
    var completedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var completedFiles = 0
    var totalFiles = 0

    var fraction: Double {
        if totalBytes > 0 {
            return min(1, Double(completedBytes) / Double(totalBytes))
        }
        return totalFiles > 0 ? Double(completedFiles) / Double(totalFiles) : 0
    }
}

/// Free space and file system of a destination volume.
struct VolumeInfo: Sendable, Equatable {
    var availableBytes: Int64?
    /// e.g. "msdos" (FAT32), "exfat", "apfs".
    var fileSystem: String?

    var isFAT32: Bool {
        guard let fileSystem else { return false }
        return ["msdos", "fat32", "vfat"].contains(fileSystem.lowercased())
    }
}

/// Checks performed before writing a package.
struct BackupPreflight: Sendable, Equatable {
    var requiredBytes: Int64
    var volume: VolumeInfo
    /// Entries that cannot be stored on FAT32 (4 GB file size limit).
    var oversizedEntries: [TransferEntry]

    var hasEnoughSpace: Bool {
        guard let available = volume.availableBytes else { return true }
        return available >= requiredBytes
    }
}

/// Result of writing a package.
struct BackupResult: Sendable {
    var packageURL: URL
    var manifest: BackupManifest
    var skipped: [ImportFailure]
    /// Paths whose SHA-256 did not match after writing. Empty when verification passed.
    var verificationFailures: [String]
    var verified: Bool
    var duration: TimeInterval
}

enum BackupError: LocalizedError, Equatable {
    case insufficientSpace(required: Int64, available: Int64)
    case destinationUnavailable
    case driveDisconnected
    case notAPackage

    var errorDescription: String? {
        switch self {
        case .insufficientSpace(let required, let available):
            let requiredText = required.formatted(.byteCount(style: .file))
            let availableText = available.formatted(.byteCount(style: .file))
            return String(localized: "Not enough space on the drive: \(requiredText) needed, \(availableText) available.")
        case .destinationUnavailable:
            return String(localized: "The selected folder is not available. Reconnect the drive and choose the folder again.")
        case .driveDisconnected:
            return String(localized: "Writing stopped: the drive was disconnected or became full. The package is marked as incomplete.")
        case .notAPackage:
            return String(localized: "This folder doesn't contain a backup package created by the app.")
        }
    }
}

/// Writes the external drive package `SwiftTransfer_<yyyy-MM-dd_HHmm>/` with `manifest.json`
/// (sizes and SHA-256 of every file) and restores packages back into `ReceivedItem`s.
struct BackupPackager: Sendable {
    static let maxFAT32FileSize: Int64 = 4_294_967_295
    static let folderPrefix = "SwiftTransfer_"
    private static let logger = Logger(subsystem: "SwiftTransfer", category: "BackupPackager")

    var verifyAfterWriting = true

    init(verifyAfterWriting: Bool = true) {
        self.verifyAfterWriting = verifyAfterWriting
    }

    // MARK: Pure helpers

    static func packageFolderName(for date: Date, timeZone: TimeZone = .current) -> String {
        let parts = ICSDateFormat.calendar(in: timeZone).dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let text = String(
            format: "%04ld-%02ld-%02ld_%02ld%02ld",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0,
            parts.hour ?? 0,
            parts.minute ?? 0
        )
        return folderPrefix + text
    }

    static func oversizedForFAT32(_ entries: [TransferEntry]) -> [TransferEntry] {
        entries.filter { ($0.byteCount ?? 0) > maxFAT32FileSize }
    }

    static func volumeInfo(for url: URL) -> VolumeInfo {
        var info = VolumeInfo()
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        if let values = try? url.resourceValues(forKeys: keys) {
            if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
                info.availableBytes = important
            } else if let capacity = values.volumeAvailableCapacity {
                info.availableBytes = Int64(capacity)
            }
        }
        var stats = statfs()
        if statfs(url.path, &stats) == 0 {
            let name = withUnsafeBytes(of: stats.f_fstypename) { buffer in
                String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
            }
            info.fileSystem = name
            if info.availableBytes == nil {
                info.availableBytes = Int64(stats.f_bavail) * Int64(stats.f_bsize)
            }
        }
        return info
    }

    /// Size needed on the drive: known sizes plus a 5% margin for unknown/converted files and the manifest.
    static func preflight(entries: [TransferEntry], destination: URL) -> BackupPreflight {
        let didAccess = destination.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                destination.stopAccessingSecurityScopedResource()
            }
        }
        let known = entries.reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) }
        let required = known + known / 20 + 1_000_000
        let volume = volumeInfo(for: destination)
        return BackupPreflight(
            requiredBytes: required,
            volume: volume,
            oversizedEntries: volume.isFAT32 ? oversizedForFAT32(entries) : []
        )
    }

    // MARK: Writing

    /// Streams every entry of `content` into a new package folder inside `destination`.
    /// Unreadable entries are skipped and reported; a disconnected drive aborts with `BackupError.driveDisconnected`
    /// and leaves the package marked incomplete.
    func writePackage(
        content: any TransferContent,
        to destination: URL,
        skippingEntryIDs skipped: Set<String> = [],
        date: Date = .now,
        progress: @escaping @Sendable (BackupProgress) -> Void
    ) async throws -> BackupResult {
        let started = Date()
        let didAccess = destination.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                destination.stopAccessingSecurityScopedResource()
            }
        }
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw BackupError.destinationUnavailable
        }

        let entries = content.entries.filter { !skipped.contains($0.id) }
        let preflight = Self.preflight(entries: entries, destination: destination)
        if !preflight.hasEnoughSpace {
            throw BackupError.insufficientSpace(
                required: preflight.requiredBytes,
                available: preflight.volume.availableBytes ?? 0
            )
        }

        let packageURL = try Self.createPackageFolder(in: destination, date: date)
        // The manifest stores whole seconds (ISO 8601), so keep the in-memory copy identical.
        var manifest = BackupManifest(
            createdAt: Self.wholeSeconds(date),
            appVersion: AppConfig.appVersion,
            complete: false,
            entries: []
        )
        try? Self.writeManifest(manifest, to: packageURL)

        var state = BackupProgress(
            totalBytes: entries.reduce(0) { $0 + ($1.byteCount ?? 0) },
            totalFiles: entries.count
        )
        progress(state)
        var failures: [ImportFailure] = content.entries
            .filter { skipped.contains($0.id) }
            .map { ImportFailure(category: $0.category, path: $0.path, reason: String(localized: "Larger than 4 GB: not supported by FAT32 drives")) }

        for entry in entries {
            try Task.checkCancellation()
            let fileURL = packageURL.appendingPathComponent(entry.path)
            let bytesBefore = state.completedBytes
            let snapshot = state
            do {
                let written = try await writeEntry(entry, content: content, to: fileURL) { chunkBytes in
                    var update = snapshot
                    update.completedBytes = bytesBefore + chunkBytes
                    progress(update)
                }
                manifest.entries.append(
                    BackupManifest.Entry(
                        path: entry.path,
                        category: entry.category,
                        size: written.size,
                        sha256: written.sha256,
                        modified: entry.modificationDate.map(Self.wholeSeconds)
                    )
                )
                if let modified = entry.modificationDate {
                    try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: fileURL.path)
                }
                state.completedBytes = bytesBefore + max(written.size, entry.byteCount ?? 0)
            } catch let error as PackageWriteError {
                Self.logger.error("Package write failed: \(error.localizedDescription, privacy: .public)")
                manifest.complete = false
                try? Self.writeManifest(manifest, to: packageURL)
                throw BackupError.driveDisconnected
            } catch is CancellationError {
                try? fileManager.removeItem(at: fileURL)
                try? Self.writeManifest(manifest, to: packageURL)
                throw CancellationError()
            } catch {
                try? fileManager.removeItem(at: fileURL)
                failures.append(ImportFailure(category: entry.category, path: entry.path, reason: error.localizedDescription))
                state.completedBytes = bytesBefore + (entry.byteCount ?? 0)
            }
            state.completedFiles += 1
            progress(state)
        }

        var verificationFailures: [String] = []
        if verifyAfterWriting {
            state.phase = .verifying
            state.completedFiles = 0
            progress(state)
            let snapshot = state
            verificationFailures = try await Self.verify(manifest: manifest, in: packageURL) { done in
                var update = snapshot
                update.completedFiles = done
                progress(update)
            }
        }

        manifest.complete = verificationFailures.isEmpty
        do {
            try Self.writeManifest(manifest, to: packageURL)
        } catch {
            throw BackupError.driveDisconnected
        }
        return BackupResult(
            packageURL: packageURL,
            manifest: manifest,
            skipped: failures,
            verificationFailures: verificationFailures,
            verified: verifyAfterWriting && verificationFailures.isEmpty,
            duration: Date().timeIntervalSince(started)
        )
    }

    private func writeEntry(
        _ entry: TransferEntry,
        content: any TransferContent,
        to fileURL: URL,
        onBytes: @escaping @Sendable (Int64) -> Void
    ) async throws -> (size: Int64, sha256: String) {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fileManager.createFile(atPath: fileURL.path, contents: nil) else {
                throw PackageWriteError(underlying: CocoaError(.fileWriteUnknown))
            }
        } catch let error as PackageWriteError {
            throw error
        } catch {
            throw PackageWriteError(underlying: error)
        }
        let sink = try HashingFileSink(url: fileURL)
        defer { sink.close() }
        try await content.read(entry, offset: 0) { data in
            try sink.write(data)
            onBytes(sink.bytesWritten)
        }
        try sink.synchronize()
        return (sink.bytesWritten, sink.digestHex())
    }

    static func wholeSeconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    private static func createPackageFolder(in destination: URL, date: Date) throws -> URL {
        let baseName = packageFolderName(for: date)
        var candidate = destination.appendingPathComponent(baseName, isDirectory: true)
        var attempt = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = destination.appendingPathComponent("\(baseName)_\(attempt)", isDirectory: true)
            attempt += 1
        }
        do {
            try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
        } catch {
            throw BackupError.destinationUnavailable
        }
        return candidate
    }

    static func writeManifest(_ manifest: BackupManifest, to packageURL: URL) throws {
        let data = try manifest.encoded()
        try data.write(to: packageURL.appendingPathComponent(BackupManifest.fileName), options: .atomic)
    }

    /// Re-reads every file and compares its SHA-256 with the manifest. Returns mismatching paths.
    static func verify(
        manifest: BackupManifest,
        in packageURL: URL,
        progress: @Sendable (Int) -> Void = { _ in }
    ) async throws -> [String] {
        var mismatches: [String] = []
        for (index, entry) in manifest.entries.enumerated() {
            try Task.checkCancellation()
            let url = packageURL.appendingPathComponent(entry.path)
            let hash = try? FileHasher.sha256Hex(ofFile: url)
            if hash != entry.sha256 {
                mismatches.append(entry.path)
            }
            progress(index + 1)
            await Task.yield()
        }
        return mismatches
    }

    // MARK: Restore

    /// Files of a package folder as `ReceivedItem`s (categories from the manifest or the top-level folder).
    static func receivedItems(inPackage folder: URL) throws -> (items: [ReceivedItem], manifest: BackupManifest?) {
        let fileManager = FileManager.default
        let manifestURL = folder.appendingPathComponent(BackupManifest.fileName)
        if let data = try? Data(contentsOf: manifestURL), let manifest = try? BackupManifest.decode(from: data) {
            let items = manifest.entries.compactMap { entry -> ReceivedItem? in
                let url = folder.appendingPathComponent(entry.path)
                guard fileManager.fileExists(atPath: url.path) else { return nil }
                return ReceivedItem(category: entry.category, fileURL: url, path: entry.path)
            }
            return (items, manifest)
        }

        let categoryFolders = Dictionary(uniqueKeysWithValues: DataCategory.allCases.map { ($0.folderName.lowercased(), $0) })
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw BackupError.notAPackage
        }
        var items: [ReceivedItem] = []
        let rootPath = folder.standardizedFileURL.path
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            var relative = url.standardizedFileURL.path
            if relative.hasPrefix(rootPath) {
                relative = String(relative.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
            let top = relative.split(separator: "/").first.map { $0.lowercased() } ?? ""
            items.append(ReceivedItem(category: categoryFolders[top], fileURL: url, path: relative))
        }
        guard items.contains(where: { $0.category != nil }) else {
            throw BackupError.notAPackage
        }
        return (items, nil)
    }
}

/// A write to the destination failed (drive removed or full) — aborts the whole package.
struct PackageWriteError: LocalizedError {
    var underlying: Error

    var errorDescription: String? {
        underlying.localizedDescription
    }
}

/// Appends streamed chunks to a file while computing SHA-256. Chunks arrive sequentially.
private final class HashingFileSink: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var hasher = StreamingSHA256()
    private var written: Int64 = 0

    init(url: URL) throws {
        do {
            handle = try FileHandle(forWritingTo: url)
        } catch {
            throw PackageWriteError(underlying: error)
        }
    }

    var bytesWritten: Int64 {
        lock.withLock { written }
    }

    func write(_ data: Data) throws {
        try lock.withLock {
            do {
                try handle.write(contentsOf: data)
            } catch {
                throw PackageWriteError(underlying: error)
            }
            hasher.update(data)
            written += Int64(data.count)
        }
    }

    func synchronize() throws {
        do {
            try handle.synchronize()
        } catch {
            throw PackageWriteError(underlying: error)
        }
    }

    func digestHex() -> String {
        lock.withLock { hasher.finalizeHex() }
    }

    func close() {
        try? handle.close()
    }
}
