import Foundation
import os

// Entry points of the data layer used by transports and features:
// - `ExportService` (sender): selection → streamable `TransferContent` + per-category summaries.
// - `ImportService` (receiver): received files → Contacts/Calendar/Reminders/Photos/Files (see ImportService.swift).

/// Builds streamable content from a selection. Reads data only; never modifies the source libraries.
final class ExportService: TransferContentBuilding {
    private static let logger = Logger(subsystem: "SwiftTransfer", category: "Export")

    /// Approximate bytes per item for categories whose files are generated on demand.
    static let estimatedBytesPerContact: Int64 = 3_000
    static let estimatedBytesPerEvent: Int64 = 900
    static let estimatedBytesPerReminder: Int64 = 600

    init() {}

    func makeContent(for selection: TransferSelection) async throws -> any TransferContent {
        try await prepareContent(for: selection)
    }

    /// Same as `makeContent(for:)` but returns the concrete type with item counts.
    /// `progress` reports 0…1 while categories are being prepared.
    func prepareContent(
        for selection: TransferSelection,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ExportedContent {
        let staging = try ExportStagingDirectory()
        var builder = ContentBuilder()
        let permissions = PermissionsService()
        let categories = DataCategory.allCases.filter { selection.categories.contains($0) }

        for (index, category) in categories.enumerated() {
            try Task.checkCancellation()
            progress?(Double(index) / Double(max(categories.count, 1)))
            if let permission = PermissionKind.reading(category), !permissions.status(permission).allowsAccess {
                builder.skipped.append(category)
                continue
            }
            switch category {
            case .contacts:
                try await addContacts(selection, staging: staging, to: &builder)
            case .calendar:
                try await addCalendar(selection, staging: staging, to: &builder)
            case .reminders:
                try await addReminders(selection, staging: staging, to: &builder)
            case .photos, .videos:
                addMedia(category, selection: selection, to: &builder)
            case .files:
                addFiles(selection, to: &builder)
            }
        }
        progress?(1)
        return ExportedContent(
            entries: builder.entries,
            itemCounts: builder.counts,
            skippedCategories: builder.skipped,
            sources: builder.sources,
            staging: staging
        )
    }

    // MARK: Summaries

    /// Count and size of one category for the selection screen.
    /// Photos and videos first yield an estimate, then the exact size. Empty when access is missing.
    func summaryUpdates(for category: DataCategory, selection: TransferSelection) -> AsyncStream<SummaryUpdate> {
        if let permission = PermissionKind.reading(category), !PermissionsService().status(permission).allowsAccess {
            return AsyncStream { continuation in
                continuation.yield(SummaryUpdate(summary: CategorySummary(itemCount: 0, byteCount: 0), isFinal: true))
                continuation.finish()
            }
        }
        switch category {
        case .photos, .videos:
            return PhotosSource().summaryUpdates(category, selection: selection)
        default:
            return AsyncStream { continuation in
                let task = Task {
                    let summary = await self.summary(for: category, selection: selection)
                    continuation.yield(SummaryUpdate(summary: summary, isFinal: true))
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }

    /// Final count and size of one category (exact for media and files, estimated for generated files).
    func summary(for category: DataCategory, selection: TransferSelection) async -> CategorySummary {
        if let permission = PermissionKind.reading(category), !PermissionsService().status(permission).allowsAccess {
            return CategorySummary(itemCount: 0, byteCount: 0)
        }
        switch category {
        case .contacts:
            let count = (try? await ContactsSource().count(containerIDs: selection.contactContainerIDs)) ?? 0
            return CategorySummary(itemCount: count, byteCount: Int64(count) * Self.estimatedBytesPerContact)
        case .calendar:
            let interval = CalendarSource.interval(for: selection)
            let count = await CalendarSource().count(calendarIDs: selection.calendarIDs, interval: interval)
            return CategorySummary(itemCount: count, byteCount: Int64(count) * Self.estimatedBytesPerEvent)
        case .reminders:
            let count = await RemindersSource().count(
                listIDs: selection.reminderListIDs,
                includeCompleted: selection.includeCompletedReminders
            )
            return CategorySummary(itemCount: count, byteCount: Int64(count) * Self.estimatedBytesPerReminder)
        case .photos, .videos:
            var last = CategorySummary(itemCount: 0, byteCount: 0)
            for await update in PhotosSource().summaryUpdates(category, selection: selection) {
                last = update.summary
            }
            return last
        case .files:
            return FilesSource.summary(for: selection.fileURLs)
        }
    }

    /// Removes leftovers of earlier export sessions (call at app start, TZ §10).
    static func removeTemporaryFiles() {
        try? FileManager.default.removeItem(at: ExportStagingDirectory.rootURL)
    }

    // MARK: Categories

    private func addContacts(_ selection: TransferSelection, staging: ExportStagingDirectory, to builder: inout ContentBuilder) async throws {
        let url = try staging.fileURL("Contacts/contacts.vcf")
        let count = try await ContactsSource().writeVCard(to: url, containerIDs: selection.contactContainerIDs)
        guard count > 0 else { return }
        builder.addFile(id: "contacts", category: .contacts, path: "Contacts/contacts.vcf", url: url)
        builder.counts[.contacts] = count
    }

    private func addCalendar(_ selection: TransferSelection, staging: ExportStagingDirectory, to builder: inout ContentBuilder) async throws {
        let interval = CalendarSource.interval(for: selection)
        let events = await CalendarSource().events(calendarIDs: selection.calendarIDs, interval: interval)
        guard !events.isEmpty else { return }
        let document = ICSWriter().document(events: events, calendarName: String(localized: "Calendar"))
        let url = try staging.fileURL("Calendar/calendar.ics")
        try Data(document.utf8).write(to: url)
        builder.addFile(id: "calendar", category: .calendar, path: "Calendar/calendar.ics", url: url)
        builder.counts[.calendar] = events.count
    }

    private func addReminders(_ selection: TransferSelection, staging: ExportStagingDirectory, to builder: inout ContentBuilder) async throws {
        let lists = await RemindersSource().reminders(
            listIDs: selection.reminderListIDs,
            includeCompleted: selection.includeCompletedReminders
        )
        let todos = lists.flatMap(\.items)
        guard !todos.isEmpty else { return }
        let icsURL = try staging.fileURL("Reminders/reminders.ics")
        try Data(ICSWriter().document(todos: todos, calendarName: String(localized: "Reminders")).utf8).write(to: icsURL)
        let textURL = try staging.fileURL("Reminders/reminders.txt")
        try Data(RemindersTextWriter().text(for: lists).utf8).write(to: textURL)
        builder.addFile(id: "reminders-ics", category: .reminders, path: "Reminders/reminders.ics", url: icsURL)
        builder.addFile(id: "reminders-txt", category: .reminders, path: "Reminders/reminders.txt", url: textURL)
        builder.counts[.reminders] = todos.count
    }

    private func addMedia(_ category: DataCategory, selection: TransferSelection, to builder: inout ContentBuilder) {
        let assets = PhotosSource().assets(category, selection: selection)
        let quality = category == .videos ? selection.videoQuality : selection.photoQuality
        for asset in assets {
            let folder = category.folderName + "/" + Self.monthFolder(for: asset.creationDate)
            let primaryExtension: String
            let primarySource: ExportEntrySource
            var knownSize = asset.primary.byteCount
            let originalExtension = (asset.primary.originalFilename as NSString).pathExtension

            if category == .photos && quality == .compatible && asset.primary.isHEIF {
                primaryExtension = "JPG"
                primarySource = .jpegConversion(asset.primary)
                knownSize = nil
            } else if category == .videos && quality == .compatible {
                primaryExtension = "MP4"
                primarySource = .videoConversion(asset.primary)
                knownSize = nil
            } else {
                primaryExtension = originalExtension
                primarySource = .asset(asset.primary)
            }

            var extensions = [primaryExtension]
            if let paired = asset.pairedVideo {
                let pairedExtension = (paired.originalFilename as NSString).pathExtension
                extensions.append(pairedExtension.isEmpty ? "MOV" : pairedExtension)
            }
            let paths = builder.names.allocate(folder: folder, baseName: asset.baseName, extensions: extensions)
            let prefix = category == .videos ? "video" : "photo"
            builder.add(
                TransferEntry(
                    id: "\(prefix):\(asset.id)",
                    category: category,
                    path: paths[0],
                    byteCount: knownSize,
                    modificationDate: asset.creationDate
                ),
                source: primarySource
            )
            if let paired = asset.pairedVideo, paths.count > 1 {
                builder.add(
                    TransferEntry(
                        id: "\(prefix)-live:\(asset.id)",
                        category: category,
                        path: paths[1],
                        byteCount: paired.byteCount,
                        modificationDate: asset.creationDate
                    ),
                    source: .asset(paired)
                )
            }
        }
        if !assets.isEmpty {
            builder.counts[category] = assets.count
        }
    }

    private func addFiles(_ selection: TransferSelection, to builder: inout ContentBuilder) {
        let items = FilesSource.items(for: selection.fileURLs)
        for (index, item) in items.enumerated() {
            let relative = item.relativePath as NSString
            let folder = relative.deletingLastPathComponent
            let path = builder.names.allocate(
                folder: FileNameAllocator.join(DataCategory.files.folderName, folder),
                fileName: relative.lastPathComponent
            )
            builder.add(
                TransferEntry(
                    id: "file:\(index)",
                    category: .files,
                    path: path,
                    byteCount: item.byteCount,
                    modificationDate: item.modificationDate
                ),
                source: .scopedFile(item.url, scope: item.scopeURL)
            )
        }
        if !items.isEmpty {
            builder.counts[.files] = items.count
        }
    }

    /// `YYYY-MM` folder for a creation date, "Undated" when unknown.
    static func monthFolder(for date: Date?) -> String {
        guard let date else { return "Undated" }
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04ld-%02ld", parts.year ?? 0, parts.month ?? 0)
    }
}

/// Accumulates entries while preparing content.
private struct ContentBuilder {
    var entries: [TransferEntry] = []
    var sources: [String: ExportEntrySource] = [:]
    var counts: [DataCategory: Int] = [:]
    var skipped: [DataCategory] = []
    var names = FileNameAllocator()

    mutating func add(_ entry: TransferEntry, source: ExportEntrySource) {
        entries.append(entry)
        sources[entry.id] = source
    }

    mutating func addFile(id: String, category: DataCategory, path: String, url: URL) {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        add(
            TransferEntry(
                id: id,
                category: category,
                path: names.allocate(folder: (path as NSString).deletingLastPathComponent, fileName: (path as NSString).lastPathComponent),
                byteCount: Int64(values?.fileSize ?? 0),
                modificationDate: .now
            ),
            source: .file(url)
        )
    }
}

/// Where the bytes of an entry come from.
enum ExportEntrySource: Sendable, Hashable {
    /// A file generated in the staging directory (vCard, ICS, TXT).
    case file(URL)
    /// A user-picked file; `scope` is the security-scoped URL to access while reading.
    case scopedFile(URL, scope: URL)
    /// A photo library resource streamed as is.
    case asset(MediaResourceInfo)
    /// HEIC converted to JPEG on first read.
    case jpegConversion(MediaResourceInfo)
    /// Video converted to H.264 on first read.
    case videoConversion(MediaResourceInfo)
}

/// Temporary folder of one export session; removed when the content is released.
final class ExportStagingDirectory: Sendable {
    static var rootURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("SwiftTransferExport", isDirectory: true)
    }

    let url: URL

    init() throws {
        url = Self.rootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }

    var conversionCacheURL: URL {
        url.appendingPathComponent("Converted", isDirectory: true)
    }

    func fileURL(_ relativePath: String) throws -> URL {
        let fileURL = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        return fileURL
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Content prepared by `ExportService`: generated files, photo library resources and picked files.
/// Reads support an offset for resume / HTTP Range.
struct ExportedContent: TransferContent {
    let entries: [TransferEntry]
    /// Number of items per category (contacts, events, reminders, photos, videos, files).
    let itemCounts: [DataCategory: Int]
    /// Selected categories skipped because access was not granted.
    let skippedCategories: [DataCategory]
    let sources: [String: ExportEntrySource]
    let staging: ExportStagingDirectory

    static let chunkSize = 1 << 20

    /// Sum of the known entry sizes.
    var knownByteCount: Int64 {
        entries.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }

    func read(
        _ entry: TransferEntry,
        offset: Int64,
        into sink: @Sendable (Data) async throws -> Void
    ) async throws {
        guard let source = sources[entry.id] else {
            throw CocoaError(.fileNoSuchFile)
        }
        let exporter = MediaExporter()
        switch source {
        case .file(let url):
            try await Self.streamFile(url, offset: offset, into: sink)
        case .scopedFile(let url, let scope):
            let didAccess = scope.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    scope.stopAccessingSecurityScopedResource()
                }
            }
            try await Self.streamFile(url, offset: offset, into: sink)
        case .asset(let info):
            try await exporter.stream(info, offset: offset, into: sink)
        case .jpegConversion(let info):
            let url = try await exporter.convertedPhoto(info, cacheDirectory: staging.conversionCacheURL)
            try await Self.streamFile(url, offset: offset, into: sink)
        case .videoConversion(let info):
            let url = try await exporter.convertedVideo(info, cacheDirectory: staging.conversionCacheURL)
            try await Self.streamFile(url, offset: offset, into: sink)
        }
    }

    /// Streams a local file from `offset` in 1 MB chunks.
    static func streamFile(_ url: URL, offset: Int64, into sink: @Sendable (Data) async throws -> Void) async throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        if offset > 0 {
            try handle.seek(toOffset: UInt64(offset))
        }
        while true {
            try Task.checkCancellation()
            let chunk = try autoreleasepool { try handle.read(upToCount: chunkSize) }
            guard let chunk, !chunk.isEmpty else { break }
            try await sink(chunk)
        }
    }
}
