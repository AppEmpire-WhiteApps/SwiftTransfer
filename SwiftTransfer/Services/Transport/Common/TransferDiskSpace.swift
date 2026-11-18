import Foundation

/// Free space and temporary folders used by receivers.
enum TransferDiskSpace {
    /// Free space for important usage on the volume containing `url` (default: temporary directory).
    static func availableCapacity(at url: URL = FileManager.default.temporaryDirectory) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    /// Safety margin kept free when accepting incoming data.
    static let reserve: Int64 = 200 * 1024 * 1024

    static func hasRoom(for bytes: Int64, at url: URL = FileManager.default.temporaryDirectory) -> Bool {
        guard let free = availableCapacity(at: url) else { return true }
        return bytes + reserve <= free
    }

    /// Creates (if needed) a protected temporary folder for a receiving session.
    static func makeSessionDirectory(kind: String, session: String = UUID().uuidString) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(kind, isDirectory: true)
        let url = root.appendingPathComponent(session, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        return url
    }

    /// Deletes leftover temporary folders of earlier sessions (call at app start or session end).
    static func removeSessionDirectories(kind: String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(kind, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
    }

    /// A file name safe for the local file system: no separators or control characters.
    static func sanitizedFileName(_ name: String) -> String {
        let last = name.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? name
        var cleaned = String(last.unicodeScalars.filter { scalar in
            scalar.value >= 0x20 && scalar != ":" && scalar.value != 0x7F
        }.map(Character.init))
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix(".") {
            cleaned.removeFirst()
        }
        if cleaned.count > 180 {
            let ext = (cleaned as NSString).pathExtension
            let stem = String((cleaned as NSString).deletingPathExtension.prefix(160))
            cleaned = ext.isEmpty ? stem : "\(stem).\(ext)"
        }
        return cleaned.isEmpty ? "file" : cleaned
    }

    /// A URL inside `directory` that does not exist yet ("name (1).ext" on collision).
    static func uniqueURL(for name: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(name)
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(stem) (\(counter))" : "\(stem) (\(counter)).\(ext)"
            candidate = directory.appendingPathComponent(numbered)
            counter += 1
        }
        return candidate
    }

    /// Best-effort category guess from a file extension (used for display; importers decide on their own).
    static func guessCategory(forFileName name: String) -> DataCategory {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "heic", "heif", "png", "gif", "webp", "dng", "tif", "tiff", "bmp":
            return .photos
        case "mov", "mp4", "m4v", "3gp", "mkv", "webm", "avi":
            return .videos
        case "vcf":
            return .contacts
        case "ics":
            return .calendar
        default:
            return .files
        }
    }
}
