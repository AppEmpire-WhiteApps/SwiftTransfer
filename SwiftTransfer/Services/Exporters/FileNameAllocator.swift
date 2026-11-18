import Foundation

/// Allocates unique file names inside folders: `IMG_0001.HEIC`, then `IMG_0001 (1).HEIC`, …
/// Comparison is case-insensitive so the result is safe on FAT/exFAT and APFS.
struct FileNameAllocator: Sendable {
    private var used: Set<String> = []

    init() {}

    /// Reserves a unique path `folder/name` and returns it.
    mutating func allocate(folder: String, fileName: String) -> String {
        allocate(folder: folder, baseName: Self.baseName(of: fileName), extensions: [Self.pathExtension(of: fileName)])[0]
    }

    /// Reserves one shared base name for several extensions (e.g. a Live Photo `.HEIC` + `.MOV` pair).
    mutating func allocate(folder: String, baseName: String, extensions: [String]) -> [String] {
        let safeBase = Self.sanitize(baseName.isEmpty ? "file" : baseName)
        var attempt = 0
        while true {
            let candidateBase = attempt == 0 ? safeBase : "\(safeBase) (\(attempt))"
            let paths = extensions.map { ext in
                Self.join(folder, ext.isEmpty ? candidateBase : candidateBase + "." + ext)
            }
            let keys = paths.map { $0.lowercased() }
            if keys.allSatisfy({ !used.contains($0) }) && Set(keys).count == keys.count {
                used.formUnion(keys)
                return paths
            }
            attempt += 1
        }
    }

    static func baseName(of fileName: String) -> String {
        (fileName as NSString).deletingPathExtension
    }

    static func pathExtension(of fileName: String) -> String {
        (fileName as NSString).pathExtension
    }

    static func join(_ folder: String, _ name: String) -> String {
        folder.isEmpty ? name : folder + "/" + name
    }

    /// Removes characters that are invalid on FAT/exFAT volumes or in ZIP paths.
    static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        let cleaned = name.unicodeScalars.map { invalid.contains($0) ? "_" : String($0) }.joined()
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return trimmed.isEmpty ? "file" : trimmed
    }
}
