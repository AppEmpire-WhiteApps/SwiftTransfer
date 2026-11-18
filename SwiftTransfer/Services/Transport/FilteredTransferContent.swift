import Foundation

/// A subset of another content's entries (used by "Retry failed").
struct FilteredTransferContent: TransferContent {
    let base: any TransferContent
    let entries: [TransferEntry]

    init(base: any TransferContent, entryIDs: Set<String>) {
        self.base = base
        self.entries = base.entries.filter { entryIDs.contains($0.id) }
    }

    init(base: any TransferContent, paths: Set<String>) {
        self.base = base
        self.entries = base.entries.filter { paths.contains($0.path) }
    }

    func read(
        _ entry: TransferEntry,
        offset: Int64,
        into sink: @Sendable (Data) async throws -> Void
    ) async throws {
        try await base.read(entry, offset: offset, into: sink)
    }
}
