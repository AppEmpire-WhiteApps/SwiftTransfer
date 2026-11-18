import Foundation
import os
import UniformTypeIdentifiers

/// Imports received files into Contacts, Calendar, Reminders, Photos and Files (receiver side).
/// Only adds data; created identifiers are returned so the import can be undone.
final class ImportService: ReceivedItemsImporting {
    private static let logger = Logger(subsystem: "SwiftTransfer", category: "Import")
    /// Space kept free on the device when saving media and files.
    static let reservedBytes: Int64 = 200_000_000

    init() {}

    func importItems(
        _ items: [ReceivedItem],
        policy: DuplicatePolicy,
        progress: @escaping @Sendable (_ done: Int, _ total: Int) -> Void
    ) async -> ImportReport {
        var session = ImportSession(policy: policy, total: items.count, progress: progress)
        let classified = items.map { (item: $0, category: Self.detectCategory(for: $0)) }
        progress(0, items.count)

        // Contacts
        let vcards = classified.filter { $0.category == .contacts && Self.isVCard($0.item) }
        if !vcards.isEmpty {
            await session.importContacts(vcards.map(\.item))
        }

        // Calendars and reminders (both can live in any .ics file)
        let calendars = classified.filter { Self.isICS($0.item) && ($0.category == .calendar || $0.category == .reminders) }
        if !calendars.isEmpty {
            await session.importCalendars(calendars.map(\.item))
        }
        let hasRemindersICS = calendars.contains { $0.category == .reminders }

        // Photos and videos
        let media = classified.filter { ($0.category == .photos || $0.category == .videos) && Self.isMedia($0.item) }
        if !media.isEmpty {
            await session.importMedia(media.map { ($0.item.fileURL, $0.item.path, $0.category) })
        }

        // Everything else goes to Files.
        let handledPaths = Set((vcards + calendars + media).map(\.item.path))
        for entry in classified where !handledPaths.contains(entry.item.path) {
            if entry.category == .reminders && hasRemindersICS && entry.item.fileURL.pathExtension.lowercased() == "txt" {
                // reminders.txt duplicates reminders.ics on iOS receivers.
                session.advance()
                continue
            }
            session.saveFile(entry.item, category: entry.category)
        }
        return session.report
    }

    func undoImport(_ created: CreatedIdentifiers) async throws {
        if !created.contacts.isEmpty {
            try ContactsImporter().delete(identifiers: created.contacts)
        }
        if !created.events.isEmpty {
            try CalendarImporter().delete(identifiers: created.events)
        }
        if !created.reminders.isEmpty {
            try RemindersImporter().delete(identifiers: created.reminders)
        }
        if !created.assets.isEmpty {
            try await PhotosImporter().delete(identifiers: created.assets)
        }
    }

    // MARK: Classification

    /// Category from the top-level package folder, otherwise from the file type.
    static func detectCategory(for item: ReceivedItem) -> DataCategory {
        if let category = item.category {
            return category
        }
        if let top = item.path.split(separator: "/").first, item.path.contains("/"),
           let category = DataCategory.allCases.first(where: { $0.folderName.caseInsensitiveCompare(String(top)) == .orderedSame }) {
            return category
        }
        let ext = item.fileURL.pathExtension.lowercased()
        switch ext {
        case "vcf", "vcard":
            return .contacts
        case "ics", "ical", "ifb", "icalendar":
            return .calendar
        default:
            break
        }
        if PhotosImporter.photoExtensions.contains(ext) {
            return .photos
        }
        if PhotosImporter.videoExtensions.contains(ext) {
            return .videos
        }
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .image) {
                return .photos
            }
            if type.conforms(to: .movie) {
                return .videos
            }
        }
        return .files
    }

    static func isVCard(_ item: ReceivedItem) -> Bool {
        ["vcf", "vcard"].contains(item.fileURL.pathExtension.lowercased())
    }

    static func isICS(_ item: ReceivedItem) -> Bool {
        ["ics", "ical", "ifb", "icalendar"].contains(item.fileURL.pathExtension.lowercased())
    }

    static func isMedia(_ item: ReceivedItem) -> Bool {
        let ext = item.fileURL.pathExtension.lowercased()
        return PhotosImporter.photoExtensions.contains(ext) || PhotosImporter.videoExtensions.contains(ext)
    }
}

/// Mutable state of one import run.
private struct ImportSession {
    let policy: DuplicatePolicy
    let total: Int
    let progress: @Sendable (Int, Int) -> Void
    var report = ImportReport()
    var done = 0
    var remainingCapacity = ReceivedFilesStore.availableCapacity()
    private let permissions = PermissionsService()

    init(policy: DuplicatePolicy, total: Int, progress: @escaping @Sendable (Int, Int) -> Void) {
        self.policy = policy
        self.total = total
        self.progress = progress
    }

    mutating func advance(by count: Int = 1) {
        done = min(total, done + count)
        progress(done, total)
    }

    mutating func fail(_ item: ReceivedItem, category: DataCategory?, reason: String) {
        report.failures.append(ImportFailure(category: category, path: item.path, reason: reason))
    }

    private func hasAccess(for category: DataCategory) async -> Bool {
        guard let kind = PermissionKind.importing(category) else { return true }
        return await permissions.request(kind).allowsAccess
    }

    // MARK: Contacts

    mutating func importContacts(_ items: [ReceivedItem]) async {
        guard await hasAccess(for: .contacts) else {
            for item in items {
                fail(item, category: .contacts, reason: ImportError.noAccess(.contacts).localizedDescription)
                advance()
            }
            return
        }
        let importer = ContactsImporter()
        for item in items {
            do {
                let outcome = try importer.importVCard(at: item.fileURL, policy: policy)
                report.imported[.contacts, default: 0] += outcome.imported
                report.skippedDuplicates[.contacts, default: 0] += outcome.skipped
                report.created.contacts += outcome.created
            } catch {
                fail(item, category: .contacts, reason: error.localizedDescription)
            }
            advance()
        }
    }

    // MARK: Calendar and reminders

    mutating func importCalendars(_ items: [ReceivedItem]) async {
        let parser = ICSParser()
        var calendarImporter: CalendarImporter?
        var remindersImporter: RemindersImporter?
        var calendarAccess: Bool?
        var remindersAccess: Bool?

        for item in items {
            guard let data = try? Data(contentsOf: item.fileURL) else {
                fail(item, category: .calendar, reason: String(localized: "The file could not be read."))
                advance()
                continue
            }
            let calendar = parser.parse(data: data)
            if calendar.events.isEmpty && calendar.todos.isEmpty {
                fail(item, category: .calendar, reason: String(localized: "No events or reminders found in the file."))
            }

            if !calendar.events.isEmpty {
                if calendarAccess == nil {
                    calendarAccess = await hasAccess(for: .calendar)
                }
                if calendarAccess == true {
                    do {
                        let importer = calendarImporter ?? CalendarImporter()
                        calendarImporter = importer
                        let outcome = try importer.importEvents(calendar.events, policy: policy)
                        report.imported[.calendar, default: 0] += outcome.imported
                        report.skippedDuplicates[.calendar, default: 0] += outcome.skipped
                        report.created.events += outcome.created
                    } catch {
                        fail(item, category: .calendar, reason: error.localizedDescription)
                    }
                } else {
                    fail(item, category: .calendar, reason: ImportError.noAccess(.calendar).localizedDescription)
                }
            }

            if !calendar.todos.isEmpty {
                if remindersAccess == nil {
                    remindersAccess = await hasAccess(for: .reminders)
                }
                if remindersAccess == true {
                    do {
                        let importer = remindersImporter ?? RemindersImporter()
                        remindersImporter = importer
                        let outcome = try await importer.importTodos(calendar.todos, policy: policy)
                        report.imported[.reminders, default: 0] += outcome.imported
                        report.skippedDuplicates[.reminders, default: 0] += outcome.skipped
                        report.created.reminders += outcome.created
                    } catch {
                        fail(item, category: .reminders, reason: error.localizedDescription)
                    }
                } else {
                    fail(item, category: .reminders, reason: ImportError.noAccess(.reminders).localizedDescription)
                }
            }
            advance()
        }
    }

    // MARK: Media

    mutating func importMedia(_ items: [(url: URL, path: String, category: DataCategory)]) async {
        let media = PhotosImporter.pairLivePhotos(items)
        guard await hasAccess(for: .photos) else {
            for file in media {
                report.failures.append(ImportFailure(category: file.category, path: file.path, reason: ImportError.noAccess(.photos).localizedDescription))
            }
            advance(by: items.count)
            return
        }
        let importer = PhotosImporter()
        for file in media {
            if Task.isCancelled {
                break
            }
            let size = file.byteCount
            if let remaining = remainingCapacity, remaining - size < ImportService.reservedBytes {
                report.failures.append(ImportFailure(category: file.category, path: file.path, reason: ImportError.notEnoughSpace.localizedDescription))
                advance(by: file.pairedVideoURL == nil ? 1 : 2)
                continue
            }
            do {
                switch try await importer.importMedia(file, policy: policy) {
                case .imported(let identifier):
                    report.imported[file.category, default: 0] += 1
                    report.created.assets.append(identifier)
                    remainingCapacity = remainingCapacity.map { $0 - size }
                case .skippedDuplicate:
                    report.skippedDuplicates[file.category, default: 0] += 1
                }
            } catch {
                report.failures.append(ImportFailure(category: file.category, path: file.path, reason: error.localizedDescription))
            }
            advance(by: file.pairedVideoURL == nil ? 1 : 2)
        }
    }

    // MARK: Files

    mutating func saveFile(_ item: ReceivedItem, category: DataCategory) {
        let size = ReceivedFilesStore.fileSize(item.fileURL)
        if let remaining = remainingCapacity, remaining - size < ImportService.reservedBytes {
            fail(item, category: category, reason: ImportError.notEnoughSpace.localizedDescription)
            advance()
            return
        }
        do {
            try ReceivedFilesStore.save(item)
            report.savedFiles += 1
            report.imported[.files, default: 0] += 1
            remainingCapacity = remainingCapacity.map { $0 - size }
        } catch {
            fail(item, category: category, reason: error.localizedDescription)
        }
        advance()
    }
}
