import Foundation
import UniformTypeIdentifiers

/// Pure classification shared by every transport; declaring an image as a file does not make it free.
enum PhotoTransferPolicy {
    nonisolated static func containsPhotos(in selection: TransferSelection) -> Bool {
        selection.categories.contains(.photos)
            || (selection.categories.contains(.files)
                && selection.fileURLs.contains { isPhoto(category: nil, path: $0.path) })
    }

    nonisolated static func containsPhotos(in items: [ReceivedItem]) -> Bool {
        items.contains {
            isPhoto(category: $0.category, path: $0.path)
                || isPhoto(category: nil, path: $0.fileURL.path)
        }
    }

    nonisolated static func containsPhotos(in entries: [TransferEntry]) -> Bool {
        entries.contains { isPhoto(category: $0.category, path: $0.path) }
    }

    nonisolated static func isPhoto(category: DataCategory?, path: String, mimeType: String? = nil) -> Bool {
        if category == .photos {
            return true
        }
        if let mimeType {
            let type = mimeType.components(separatedBy: ";")[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if type.hasPrefix("image/") || UTType(mimeType: type)?.conforms(to: .image) == true {
                return true
            }
        }
        let ext = (path as NSString).pathExtension.lowercased()
        return !ext.isEmpty && UTType(filenameExtension: ext)?.conforms(to: .image) == true
    }
}
