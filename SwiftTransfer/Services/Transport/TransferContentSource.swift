import Foundation

/// Builds sender content using the data layer's export service.
enum TransferContentSource {
    static func makeContent(for selection: TransferSelection) async throws -> any TransferContent {
        return try await ExportService().makeContent(for: selection)
    }
}
