import Foundation

// Contracts between the data layer (DataSources/Exporters/Importers) and the transport layer.
// The data layer produces `TransferContent`; transports stream it. Received files are handed back
// to the data layer as `ReceivedItem`s for import.

/// One file to transfer. `path` is the relative path inside a package/ZIP, e.g. "Photos/2024-05/IMG_0001.HEIC".
struct TransferEntry: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let category: DataCategory
    let path: String
    /// Exact or estimated size. Nil when unknown until read (e.g. format conversion).
    var byteCount: Int64?
    var modificationDate: Date?
}

/// Read-only, streamable content prepared for one transfer session.
protocol TransferContent: Sendable {
    var entries: [TransferEntry] { get }

    /// Streams the entry bytes starting at `offset` in chunks to `sink`. Never loads whole media files into memory.
    func read(
        _ entry: TransferEntry,
        offset: Int64,
        into sink: @Sendable (Data) async throws -> Void
    ) async throws
}

/// Builds streamable content from a selection (sender side). Implemented by `ExportService`.
protocol TransferContentBuilding: Sendable {
    func makeContent(for selection: TransferSelection) async throws -> any TransferContent
}

/// Imports received files into Contacts/Calendar/Reminders/Photos/Files (receiver side). Implemented by `ImportService`.
protocol ReceivedItemsImporting: Sendable {
    func importItems(
        _ items: [ReceivedItem],
        policy: DuplicatePolicy,
        progress: @escaping @Sendable (_ done: Int, _ total: Int) -> Void
    ) async -> ImportReport

    /// Deletes only records created by an earlier import ("Undo import").
    func undoImport(_ created: CreatedIdentifiers) async throws
}

/// Per-category summary shown on the data selection screen.
struct CategorySummary: Sendable, Equatable {
    var itemCount: Int
    var byteCount: Int64
}

/// A file received on this device, ready to import.
struct ReceivedItem: Sendable, Hashable {
    /// Category if known (P2P manifest or package folder); nil means detect from the file type.
    var category: DataCategory?
    var fileURL: URL
    var path: String
}

struct ImportFailure: Sendable, Codable, Hashable {
    var category: DataCategory?
    var path: String
    var reason: String
}

/// Identifiers of records created by an import, kept to support "Undo import".
struct CreatedIdentifiers: Sendable, Codable, Equatable {
    var contacts: [String] = []
    var events: [String] = []
    var reminders: [String] = []
    var assets: [String] = []
}

struct ImportReport: Sendable, Codable, Equatable {
    var imported: [DataCategory: Int] = [:]
    var skippedDuplicates: [DataCategory: Int] = [:]
    /// Files saved to the app's Documents folder (visible in the Files app).
    var savedFiles: Int = 0
    var failures: [ImportFailure] = []
    var created = CreatedIdentifiers()
}
