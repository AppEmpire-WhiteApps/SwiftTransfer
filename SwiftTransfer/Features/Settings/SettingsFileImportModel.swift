import Foundation
import Observation
import UniformTypeIdentifiers

/// Imports .vcf/.ics files picked in Settings through `ImportService`.
@MainActor
@Observable
final class SettingsFileImportModel {
    private(set) var isImporting = false

    static var allowedTypes: [UTType] {
        var types: [UTType] = [.vCard, .calendarEvent]
        if let ics = UTType(filenameExtension: "ics"), !types.contains(ics) {
            types.append(ics)
        }
        return types
    }

    /// Copies the picked files into a temporary folder, imports them and returns a summary alert.
    func importFiles(_ urls: [URL], policy: DuplicatePolicy) async -> SettingsNotice {
        isImporting = true
        defer { isImporting = false }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsImport-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let items: [ReceivedItem]
        do {
            items = try Self.copyItems(urls, to: folder)
        } catch {
            return SettingsNotice(
                title: String(localized: "Couldn't open the file"),
                message: error.localizedDescription
            )
        }
        guard !items.isEmpty else {
            return SettingsNotice(
                title: String(localized: "Nothing to import"),
                message: String(localized: "Choose a .vcf or .ics file.")
            )
        }

        let report = await ImportService().importItems(items, policy: policy) { _, _ in }
        return Self.notice(for: report)
    }

    nonisolated static func category(for url: URL) -> DataCategory? {
        switch url.pathExtension.lowercased() {
        case "vcf", "vcard": .contacts
        case "ics", "ical", "icalendar": .calendar
        default: nil
        }
    }

    private static func copyItems(_ urls: [URL], to folder: URL) throws -> [ReceivedItem] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var items: [ReceivedItem] = []
        for (offset, url) in urls.enumerated() {
            guard let category = category(for: url) else { continue }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let destination = folder.appendingPathComponent("\(offset)-\(url.lastPathComponent)")
            try FileManager.default.copyItem(at: url, to: destination)
            items.append(ReceivedItem(category: category, fileURL: destination, path: url.lastPathComponent))
        }
        return items
    }

    static func notice(for report: ImportReport) -> SettingsNotice {
        var lines: [String] = []
        if let contacts = report.imported[.contacts], contacts > 0 {
            lines.append(String(localized: "Contacts added: \(contacts)"))
        }
        if let events = report.imported[.calendar], events > 0 {
            lines.append(String(localized: "Events added: \(events)"))
        }
        if let reminders = report.imported[.reminders], reminders > 0 {
            lines.append(String(localized: "Reminders added: \(reminders)"))
        }
        let skipped = report.skippedDuplicates.values.reduce(0, +)
        if skipped > 0 {
            lines.append(String(localized: "Duplicates skipped: \(skipped)"))
        }
        if !report.failures.isEmpty {
            lines.append(String(localized: "Couldn't import: \(report.failures.count)"))
        }

        let importedTotal = report.imported.values.reduce(0, +)
        let title: String
        if importedTotal == 0 && !report.failures.isEmpty {
            title = String(localized: "Import failed")
        } else if importedTotal == 0 {
            title = String(localized: "Nothing new to import")
        } else {
            title = String(localized: "Import finished")
        }
        if lines.isEmpty {
            lines.append(String(localized: "No new items were found in the file."))
        }
        return SettingsNotice(title: title, message: lines.joined(separator: "\n"))
    }
}
