import Foundation
import Photos

/// A photo album (user album or smart album) shown in the photo/video options.
struct PhotoAlbumInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let photoCount: Int
    let videoCount: Int
    let isSmartAlbum: Bool
}

/// One resource (file) of an asset, identified well enough to request it again later.
struct MediaResourceInfo: Sendable, Hashable {
    let assetID: String
    let resourceTypeRaw: Int
    let originalFilename: String
    let uniformTypeIdentifier: String
    /// Size from PhotoKit metadata, without loading data. Nil if unknown.
    let byteCount: Int64?

    var isHEIF: Bool {
        let type = uniformTypeIdentifier.lowercased()
        let ext = (originalFilename as NSString).pathExtension.lowercased()
        return type.contains("heic") || type.contains("heif") || ext == "heic" || ext == "heif"
    }
}

/// A photo or video ready to be exported: current (edited) version plus an optional Live Photo video.
struct MediaAssetInfo: Sendable, Hashable {
    let id: String
    let category: DataCategory
    let creationDate: Date?
    let primary: MediaResourceInfo
    let pairedVideo: MediaResourceInfo?
    /// Original base name, e.g. "IMG_0001".
    let baseName: String

    var byteCount: Int64 {
        (primary.byteCount ?? 0) + (pairedVideo?.byteCount ?? 0)
    }
}

/// Read-only access to the photo library. Has no write methods (TZ §4.10).
struct PhotosSource: Sendable {
    init() {}

    /// User albums and useful smart albums that contain photos or videos.
    func albums() -> [PhotoAlbumInfo] {
        var result: [PhotoAlbumInfo] = []
        let smartSubtypes: [PHAssetCollectionSubtype] = [
            .smartAlbumFavorites,
            .smartAlbumSelfPortraits,
            .smartAlbumLivePhotos,
            .smartAlbumPanoramas,
            .smartAlbumScreenshots,
            .smartAlbumVideos,
            .smartAlbumSlomoVideos,
        ]
        for subtype in smartSubtypes {
            let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
            collections.enumerateObjects { collection, _, _ in
                if let info = Self.albumInfo(collection, isSmart: true) {
                    result.append(info)
                }
            }
        }
        var userAlbums: [PhotoAlbumInfo] = []
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        albums.enumerateObjects { collection, _, _ in
            if let info = Self.albumInfo(collection, isSmart: false) {
                userAlbums.append(info)
            }
        }
        userAlbums.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return result + userAlbums
    }

    /// Number of assets matching the selection (fast, no resource lookups).
    func count(_ category: DataCategory, selection: TransferSelection) -> Int {
        fetchAssets(category, selection: selection).count
    }

    /// Resolves resources of every selected asset. Can take a few seconds for large libraries.
    func assets(_ category: DataCategory, selection: TransferSelection) -> [MediaAssetInfo] {
        fetchAssets(category, selection: selection).compactMap { asset in
            autoreleasepool { Self.mediaInfo(for: asset, category: category) }
        }
    }

    /// Streams count and size: first an estimate from a sample, then the exact total.
    func summaryUpdates(_ category: DataCategory, selection: TransferSelection) -> AsyncStream<SummaryUpdate> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                let assets = fetchAssets(category, selection: selection)
                let total = assets.count
                guard total > 0 else {
                    continuation.yield(SummaryUpdate(summary: CategorySummary(itemCount: 0, byteCount: 0), isFinal: true))
                    continuation.finish()
                    return
                }
                var bytes: Int64 = 0
                for (index, asset) in assets.enumerated() {
                    if Task.isCancelled {
                        break
                    }
                    bytes += autoreleasepool {
                        Self.mediaInfo(for: asset, category: category)?.byteCount ?? 0
                    }
                    let processed = index + 1
                    if processed == min(200, total) || (processed % 2000 == 0 && processed < total) {
                        let estimate = bytes / Int64(processed) * Int64(total)
                        let summary = CategorySummary(itemCount: total, byteCount: estimate)
                        continuation.yield(SummaryUpdate(summary: summary, isFinal: processed == total))
                    }
                }
                continuation.yield(SummaryUpdate(summary: CategorySummary(itemCount: total, byteCount: bytes), isFinal: true))
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: Fetching

    private func fetchAssets(_ category: DataCategory, selection: TransferSelection) -> [PHAsset] {
        let isVideo = category == .videos
        let options = PHFetchOptions()
        options.includeHiddenAssets = selection.includeHiddenPhotos
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var predicates = [NSPredicate(format: "mediaType == %d", (isVideo ? PHAssetMediaType.video : .image).rawValue)]
        if let range = isVideo ? selection.videoDateRange : selection.photoDateRange {
            predicates.append(NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                range.lowerBound as NSDate,
                range.upperBound as NSDate
            ))
        }
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        if !isVideo, let picked = selection.pickedAssetIDs {
            return Self.array(PHAsset.fetchAssets(withLocalIdentifiers: picked, options: options))
        }
        if let albumIDs = isVideo ? selection.videoAlbumIDs : selection.photoAlbumIDs {
            var seen = Set<String>()
            var result: [PHAsset] = []
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: Array(albumIDs), options: nil)
            collections.enumerateObjects { collection, _, _ in
                PHAsset.fetchAssets(in: collection, options: options).enumerateObjects { asset, _, _ in
                    if seen.insert(asset.localIdentifier).inserted {
                        result.append(asset)
                    }
                }
            }
            return result
        }
        return Self.array(PHAsset.fetchAssets(with: options))
    }

    private static func array(_ result: PHFetchResult<PHAsset>) -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private static func albumInfo(_ collection: PHAssetCollection, isSmart: Bool) -> PhotoAlbumInfo? {
        let photos = PHFetchOptions()
        photos.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let videos = PHFetchOptions()
        videos.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        let photoCount = PHAsset.fetchAssets(in: collection, options: photos).count
        let videoCount = PHAsset.fetchAssets(in: collection, options: videos).count
        guard photoCount + videoCount > 0 else { return nil }
        return PhotoAlbumInfo(
            id: collection.localIdentifier,
            title: collection.localizedTitle ?? "",
            photoCount: photoCount,
            videoCount: videoCount,
            isSmartAlbum: isSmart
        )
    }

    // MARK: Resources

    static func mediaInfo(for asset: PHAsset, category: DataCategory) -> MediaAssetInfo? {
        let resources = PHAssetResource.assetResources(for: asset)
        func first(_ type: PHAssetResourceType) -> PHAssetResource? {
            resources.first { $0.type == type }
        }
        let isVideo = asset.mediaType == .video
        let original = isVideo ? first(.video) : (first(.photo) ?? first(.alternatePhoto))
        let current = isVideo
            ? (first(.fullSizeVideo) ?? first(.video))
            : (first(.fullSizePhoto) ?? first(.photo) ?? first(.alternatePhoto))
        guard let current else { return nil }

        var paired: PHAssetResource?
        if !isVideo && asset.mediaSubtypes.contains(.photoLive) {
            paired = first(.fullSizePairedVideo) ?? first(.pairedVideo)
        }
        let baseName = ((original ?? current).originalFilename as NSString).deletingPathExtension
        return MediaAssetInfo(
            id: asset.localIdentifier,
            category: category,
            creationDate: asset.creationDate,
            primary: resourceInfo(current, assetID: asset.localIdentifier),
            pairedVideo: paired.map { resourceInfo($0, assetID: asset.localIdentifier) },
            baseName: baseName.isEmpty ? "IMG" : baseName
        )
    }

    static func resourceInfo(_ resource: PHAssetResource, assetID: String) -> MediaResourceInfo {
        MediaResourceInfo(
            assetID: assetID,
            resourceTypeRaw: resource.type.rawValue,
            originalFilename: resource.originalFilename,
            uniformTypeIdentifier: resource.uniformTypeIdentifier,
            byteCount: fileSize(of: resource)
        )
    }

    /// Size from resource metadata (does not download or read the file).
    static func fileSize(of resource: PHAssetResource) -> Int64? {
        guard resource.responds(to: NSSelectorFromString("fileSize")) else { return nil }
        if let number = resource.value(forKey: "fileSize") as? NSNumber {
            return number.int64Value
        }
        return nil
    }

    /// Finds a resource again from its identity (used when streaming).
    static func resource(for info: MediaResourceInfo) -> PHAssetResource? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [info.assetID], options: nil).firstObject else {
            return nil
        }
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first { $0.type.rawValue == info.resourceTypeRaw && $0.originalFilename == info.originalFilename }
            ?? resources.first { $0.type.rawValue == info.resourceTypeRaw }
    }
}

/// A progressive category summary. `isFinal` is false while sizes are still being estimated.
struct SummaryUpdate: Sendable, Equatable {
    var summary: CategorySummary
    var isFinal: Bool
}
