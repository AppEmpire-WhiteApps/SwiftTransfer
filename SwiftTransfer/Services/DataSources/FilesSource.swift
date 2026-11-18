import Foundation

/// A user-picked file (or a file inside a picked folder).
struct PickedFileItem: Sendable, Hashable {
    let url: URL
    /// The security-scoped URL returned by the document picker (the file itself or its parent folder).
    let scopeURL: URL
    /// Relative path inside the package, e.g. "Taxes/2024/receipt.pdf".
    let relativePath: String
    let byteCount: Int64
    let modificationDate: Date?
}

/// Read-only access to files the user picked in the document picker. Folders are walked recursively.
enum FilesSource {
    static func items(for urls: [URL]) -> [PickedFileItem] {
        var result: [PickedFileItem] = []
        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            result += items(in: url)
        }
        return result
    }

    static func summary(for urls: [URL]) -> CategorySummary {
        let all = items(for: urls)
        return CategorySummary(itemCount: all.count, byteCount: all.reduce(0) { $0 + $1.byteCount })
    }

    private static func items(in url: URL) -> [PickedFileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let values = try? url.resourceValues(forKeys: Set(keys))
        guard values?.isDirectory == true else {
            return [
                PickedFileItem(
                    url: url,
                    scopeURL: url,
                    relativePath: url.lastPathComponent,
                    byteCount: Int64(values?.fileSize ?? 0),
                    modificationDate: values?.contentModificationDate
                ),
            ]
        }

        let folderName = url.lastPathComponent
        let rootPath = url.standardizedFileURL.path
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var result: [PickedFileItem] = []
        for case let fileURL as URL in enumerator {
            guard let fileValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                  fileValues.isRegularFile == true else { continue }
            var relative = fileURL.standardizedFileURL.path
            if relative.hasPrefix(rootPath) {
                relative = String(relative.dropFirst(rootPath.count))
            }
            relative = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            result.append(
                PickedFileItem(
                    url: fileURL,
                    scopeURL: url,
                    relativePath: folderName + "/" + relative,
                    byteCount: Int64(fileValues.fileSize ?? 0),
                    modificationDate: fileValues.contentModificationDate
                )
            )
        }
        return result
    }
}
