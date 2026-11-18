import AVFoundation
import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

enum MediaExportError: LocalizedError {
    case assetUnavailable
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .assetUnavailable:
            String(localized: "The photo or video is no longer available or could not be downloaded from iCloud.")
        case .conversionFailed:
            String(localized: "The file could not be converted to a compatible format.")
        }
    }
}

/// Streams photo library resources without loading whole files into memory and performs the
/// optional "Compatible" conversions (HEIC → JPEG with metadata, HEVC → H.264).
struct MediaExporter: Sendable {
    static let jpegQuality = 0.9

    init() {}

    // MARK: Streaming

    /// Streams the resource bytes starting at `offset` into `sink`. iCloud originals are downloaded
    /// on demand (`isNetworkAccessAllowed`). Back-pressure keeps at most a few chunks in memory.
    func stream(
        _ info: MediaResourceInfo,
        offset: Int64,
        into sink: @Sendable (Data) async throws -> Void
    ) async throws {
        guard let resource = PhotosSource.resource(for: info) else {
            throw MediaExportError.assetUnavailable
        }
        let pipe = ResourceDataPipe()
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let requestID = PHAssetResourceManager.default().requestData(
            for: resource,
            options: options,
            dataReceivedHandler: { data in
                pipe.produce(data)
            },
            completionHandler: { error in
                pipe.finish(error)
            }
        )

        do {
            try await withTaskCancellationHandler {
                var position: Int64 = 0
                for try await chunk in pipe.stream {
                    defer { pipe.consumed() }
                    let chunkStart = position
                    position += Int64(chunk.count)
                    guard position > offset else { continue }
                    let skip = Int(max(0, offset - chunkStart))
                    try await sink(skip > 0 ? chunk.subdata(in: skip..<chunk.count) : chunk)
                }
            } onCancel: {
                PHAssetResourceManager.default().cancelDataRequest(requestID)
                pipe.cancel()
            }
        } catch {
            PHAssetResourceManager.default().cancelDataRequest(requestID)
            pipe.cancel()
            throw error
        }
    }

    /// Writes the full resource to a local file.
    func write(_ info: MediaResourceInfo, to url: URL) async throws {
        guard let resource = PhotosSource.resource(for: info) else {
            throw MediaExportError.assetUnavailable
        }
        try? FileManager.default.removeItem(at: url)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: Compatible mode

    /// HEIC → JPEG (quality 0.9) keeping EXIF/GPS. Cached in `cacheDirectory` so offset reads can resume.
    func convertedPhoto(_ info: MediaResourceInfo, cacheDirectory: URL) async throws -> URL {
        let name = Self.cacheName(for: info)
        let output = cacheDirectory.appendingPathComponent(name + ".jpg")
        if FileManager.default.fileExists(atPath: output.path) {
            return output
        }
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let ext = (info.originalFilename as NSString).pathExtension
        let source = cacheDirectory.appendingPathComponent(name + "-source." + (ext.isEmpty ? "heic" : ext))
        defer { try? FileManager.default.removeItem(at: source) }
        try await write(info, to: source)

        let temporary = cacheDirectory.appendingPathComponent(name + "-partial.jpg")
        try Self.convertToJPEG(source: source, destination: temporary, quality: Self.jpegQuality)
        try FileManager.default.moveItem(at: temporary, to: output)
        return output
    }

    /// HEVC → H.264 MP4 via `AVAssetExportSession`. Slow; only when the user enabled Compatible video.
    func convertedVideo(_ info: MediaResourceInfo, cacheDirectory: URL) async throws -> URL {
        let name = Self.cacheName(for: info)
        let output = cacheDirectory.appendingPathComponent(name + ".mp4")
        if FileManager.default.fileExists(atPath: output.path) {
            return output
        }
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let source = cacheDirectory.appendingPathComponent(name + "-source.mov")
        defer { try? FileManager.default.removeItem(at: source) }
        try await write(info, to: source)

        let temporary = cacheDirectory.appendingPathComponent(name + "-partial.mp4")
        try? FileManager.default.removeItem(at: temporary)
        try await Self.exportH264(source: source, destination: temporary)
        try FileManager.default.moveItem(at: temporary, to: output)
        return output
    }

    /// Re-encodes an image as JPEG. `CGImageDestinationAddImageFromSource` keeps EXIF, GPS and orientation.
    static func convertToJPEG(source: URL, destination: URL, quality: Double) throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let imageDestination = CGImageDestinationCreateWithURL(
                  destination as CFURL,
                  UTType.jpeg.identifier as CFString,
                  1,
                  nil
              ) else {
            throw MediaExportError.conversionFailed
        }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, options)
        guard CGImageDestinationFinalize(imageDestination) else {
            throw MediaExportError.conversionFailed
        }
    }

    private static func exportH264(source: URL, destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw MediaExportError.conversionFailed
        }
        session.shouldOptimizeForNetworkUse = true
        if #available(iOS 18.0, *) {
            try await session.export(to: destination, as: .mp4)
        } else {
            session.outputURL = destination
            session.outputFileType = .mp4
            await session.export()
            guard session.status == .completed else {
                throw session.error ?? MediaExportError.conversionFailed
            }
        }
    }

    private static func cacheName(for info: MediaResourceInfo) -> String {
        let raw = "\(info.assetID)-\(info.resourceTypeRaw)"
        return String(raw.map { $0.isLetter || $0.isNumber ? $0 : "_" })
    }
}

/// Bridges PhotoKit's synchronous data callbacks to an async stream with back-pressure:
/// the producer blocks while `limit` chunks are waiting to be consumed.
final class ResourceDataPipe: @unchecked Sendable {
    let stream: AsyncThrowingStream<Data, Error>
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private let condition = NSCondition()
    private let limit: Int
    private var inFlight = 0
    private var cancelled = false

    init(limit: Int = 8) {
        let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
        self.stream = stream
        self.continuation = continuation
        self.limit = limit
    }

    func produce(_ data: Data) {
        condition.lock()
        while inFlight >= limit && !cancelled {
            condition.wait()
        }
        let isCancelled = cancelled
        if !isCancelled {
            inFlight += 1
        }
        condition.unlock()
        if !isCancelled {
            continuation.yield(data)
        }
    }

    func consumed() {
        condition.lock()
        inFlight = max(0, inFlight - 1)
        condition.signal()
        condition.unlock()
    }

    func finish(_ error: Error?) {
        if let error {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }

    func cancel() {
        condition.lock()
        cancelled = true
        condition.broadcast()
        condition.unlock()
        continuation.finish()
    }
}
