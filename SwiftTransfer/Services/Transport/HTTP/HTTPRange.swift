import Foundation

/// One byte range from a `Range: bytes=...` header.
enum ByteRangeSpec: Equatable, Sendable {
    /// bytes=a-b (inclusive)
    case closed(Int64, Int64)
    /// bytes=a-
    case from(Int64)
    /// bytes=-n (last n bytes)
    case suffix(Int64)

    /// Resolves the spec against a resource size; nil when unsatisfiable.
    func resolve(size: Int64) -> ClosedRange<Int64>? {
        guard size > 0 else { return nil }
        switch self {
        case .closed(let first, let last):
            guard first <= last, first < size else { return nil }
            return first...min(last, size - 1)
        case .from(let first):
            guard first < size else { return nil }
            return first...(size - 1)
        case .suffix(let length):
            guard length > 0 else { return nil }
            return max(0, size - length)...(size - 1)
        }
    }

    /// Parses a Range header value. Returns nil when the header is malformed or not in bytes.
    static func parse(_ header: String) -> [ByteRangeSpec]? {
        let trimmed = header.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix("bytes=") else { return nil }
        let list = trimmed.dropFirst("bytes=".count)
        var result: [ByteRangeSpec] = []
        for rawPart in list.split(separator: ",") {
            let part = rawPart.trimmingCharacters(in: .whitespaces)
            guard let dash = part.firstIndex(of: "-") else { return nil }
            let startText = part[..<dash].trimmingCharacters(in: .whitespaces)
            let endText = part[part.index(after: dash)...].trimmingCharacters(in: .whitespaces)
            switch (startText.isEmpty, endText.isEmpty) {
            case (true, true):
                return nil
            case (true, false):
                guard let length = Int64(endText), length >= 0 else { return nil }
                result.append(.suffix(length))
            case (false, true):
                guard let first = Int64(startText), first >= 0 else { return nil }
                result.append(.from(first))
            case (false, false):
                guard let first = Int64(startText), let last = Int64(endText), first >= 0, last >= first else {
                    return nil
                }
                result.append(.closed(first, last))
            }
        }
        return result.isEmpty ? nil : result
    }
}

/// Decision for serving a resource of known size with an optional Range header.
enum RangeDecision: Equatable, Sendable {
    /// 200 with the whole body (no/ignored/multi-range header).
    case full
    /// 206 with one range.
    case partial(ClosedRange<Int64>)
    /// 416 Range Not Satisfiable.
    case unsatisfiable

    static func decide(rangeHeader: String?, size: Int64) -> RangeDecision {
        guard let rangeHeader, let specs = ByteRangeSpec.parse(rangeHeader) else { return .full }
        // Multiple ranges would need multipart/byteranges; serving the full body is allowed.
        guard specs.count == 1, let spec = specs.first else { return .full }
        guard let range = spec.resolve(size: size) else { return .unsatisfiable }
        return .partial(range)
    }
}
