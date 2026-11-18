import AVFoundation
import CoreLocation
import Foundation
import ImageIO
import Photos

/// A received photo or video, optionally with the paired `.mov` of a Live Photo.
struct ReceivedMedia: Sendable, Hashable {
    var url: URL
    var path: String
    var category: DataCategory
    var pairedVideoURL: URL?

    var byteCount: Int64 {
        ReceivedFilesStore.fileSize(url) + (pairedVideoURL.map(ReceivedFilesStore.fileSize) ?? 0)
    }
}

/// Saves received photos/videos with `PHAssetCreationRequest` (add only) and rebuilds Live Photos.
struct PhotosImporter: Sendable {
    enum Outcome: Sendable {
        case imported(String)
        case skippedDuplicate
    }

    static let photoExtensions: Set<String> = ["heic", "heif", "jpg", "jpeg", "png", "gif", "tif", "tiff", "dng", "webp", "bmp"]
    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "3gp", "avi", "mkv", "webm"]

    init() {}

    /// Pairs a photo with a `.mov` of the same base name in the same folder (Live Photo).
    static func pairLivePhotos(_ items: [(url: URL, path: String, category: DataCategory)]) -> [ReceivedMedia] {
        func key(_ path: String) -> String {
            (path as NSString).deletingPathExtension.lowercased()
        }
        let livePhotoStill: Set<String> = ["heic", "heif", "jpg", "jpeg"]
        var movies: [String: URL] = [:]
        for item in items where item.url.pathExtension.lowercased() == "mov" {
            movies[key(item.path)] = item.url
        }
        var pairedKeys = Set<String>()
        var result: [ReceivedMedia] = []
        for item in items where livePhotoStill.contains(item.url.pathExtension.lowercased()) {
            let itemKey = key(item.path)
            let paired = movies[itemKey]
            if paired != nil {
                pairedKeys.insert(itemKey)
            }
            result.append(ReceivedMedia(url: item.url, path: item.path, category: .photos, pairedVideoURL: paired))
        }
        for item in items where !livePhotoStill.contains(item.url.pathExtension.lowercased()) {
            let ext = item.url.pathExtension.lowercased()
            if ext == "mov" && pairedKeys.contains(key(item.path)) {
                continue
            }
            result.append(ReceivedMedia(url: item.url, path: item.path, category: item.category, pairedVideoURL: nil))
        }
        return result
    }

    func importMedia(_ media: ReceivedMedia, policy: DuplicatePolicy) async throws -> Outcome {
        let isVideo = media.category == .videos
        let metadata = isVideo ? await Self.videoMetadata(media.url) : Self.photoMetadata(media.url)
        let filename = media.url.lastPathComponent
        if policy == .skip, let date = metadata.date, Self.isDuplicate(filename: filename, date: date, isVideo: isVideo) {
            return .skippedDuplicate
        }

        let url = media.url
        let pairedURL = media.pairedVideoURL
        let pairedName = pairedURL?.lastPathComponent
        let date = metadata.date
        let coordinate = metadata.coordinate
        let box = IdentifierBox()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = filename
            request.addResource(with: isVideo ? .video : .photo, fileURL: url, options: options)
            if let pairedURL {
                let pairedOptions = PHAssetResourceCreationOptions()
                pairedOptions.originalFilename = pairedName
                request.addResource(with: .pairedVideo, fileURL: pairedURL, options: pairedOptions)
            }
            if let date {
                request.creationDate = date
            }
            if let coordinate {
                request.location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
            box.set(request.placeholderForCreatedAsset?.localIdentifier)
        }
        guard let identifier = box.value else {
            throw MediaExportError.conversionFailed
        }
        return .imported(identifier)
    }

    /// Deletes only the given assets ("Undo import"); iOS asks the user to confirm.
    func delete(identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    // MARK: Duplicates

    /// An asset with the same original file name created within one second is a duplicate.
    static func isDuplicate(filename: String, date: Date, isVideo: Bool) -> Bool {
        guard PermissionsService().status(.photos) == .authorized else { return false }
        let options = PHFetchOptions()
        options.includeHiddenAssets = true
        options.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND creationDate <= %@",
            (isVideo ? PHAssetMediaType.video : .image).rawValue,
            date.addingTimeInterval(-1) as NSDate,
            date.addingTimeInterval(1) as NSDate
        )
        let candidates = PHAsset.fetchAssets(with: options)
        var found = false
        candidates.enumerateObjects { asset, _, stop in
            let names = PHAssetResource.assetResources(for: asset).map { $0.originalFilename.lowercased() }
            if names.contains(filename.lowercased()) {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    // MARK: Metadata

    struct Metadata: Sendable {
        var date: Date?
        var coordinate: Coordinate?
    }

    struct Coordinate: Sendable {
        var latitude: Double
        var longitude: Double
    }

    /// Capture date from EXIF `DateTimeOriginal` (with offset when present), GPS position; falls back to mtime.
    static func photoMetadata(_ url: URL) -> Metadata {
        var metadata = Metadata(date: nil, coordinate: nil)
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
               let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String
                metadata.date = exifDate(original, offset: offset)
            }
            if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
               let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
               let longitude = gps[kCGImagePropertyGPSLongitude] as? Double {
                let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N"
                let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E"
                metadata.coordinate = Coordinate(
                    latitude: latitudeRef.uppercased() == "S" ? -latitude : latitude,
                    longitude: longitudeRef.uppercased() == "W" ? -longitude : longitude
                )
            }
        }
        if metadata.date == nil {
            metadata.date = ReceivedFilesStore.modificationDate(url)
        }
        return metadata
    }

    static func videoMetadata(_ url: URL) async -> Metadata {
        let asset = AVURLAsset(url: url)
        var date: Date?
        if let item = try? await asset.load(.creationDate) {
            date = try? await item.load(.dateValue)
        }
        return Metadata(date: date ?? ReceivedFilesStore.modificationDate(url), coordinate: nil)
    }

    /// Parses `yyyy:MM:dd HH:mm:ss` with an optional `+HH:MM` offset (local time otherwise).
    static func exifDate(_ text: String, offset: String?) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        if let offset, !offset.isEmpty {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            if let date = formatter.date(from: text + offset) {
                return date
            }
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.date(from: text)
    }
}

/// Carries the placeholder identifier out of a `performChanges` block.
private final class IdentifierBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: String?

    var value: String? {
        lock.withLock { storage }
    }

    func set(_ value: String?) {
        lock.withLock { storage = value }
    }
}

/// Saves other received files to `Documents/Received/` (visible in the Files app). Never overwrites.
enum ReceivedFilesStore {
    static var folderURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Received", isDirectory: true)
    }

    /// Copies the file keeping its relative folder (without the top-level category folder).
    @discardableResult
    static func save(_ item: ReceivedItem) throws -> URL {
        var components = item.path.split(separator: "/").map(String.init)
        if components.count > 1, DataCategory.allCases.contains(where: { $0.folderName.caseInsensitiveCompare(components[0]) == .orderedSame }) {
            components.removeFirst()
        }
        let fileName = FileNameAllocator.sanitize(components.popLast() ?? item.fileURL.lastPathComponent)
        var folder = folderURL
        for component in components {
            folder.appendPathComponent(FileNameAllocator.sanitize(component), isDirectory: true)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let base = FileNameAllocator.baseName(of: fileName)
        let ext = FileNameAllocator.pathExtension(of: fileName)
        var destination = folder.appendingPathComponent(fileName)
        var attempt = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            let candidate = "\(base) (\(attempt))" + (ext.isEmpty ? "" : "." + ext)
            destination = folder.appendingPathComponent(candidate)
            attempt += 1
        }
        try FileManager.default.copyItem(at: item.fileURL, to: destination)
        return destination
    }

    static func fileSize(_ url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }

    static func modificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Free space for important data on this device.
    static func availableCapacity() -> Int64? {
        let values = try? folderURL.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
