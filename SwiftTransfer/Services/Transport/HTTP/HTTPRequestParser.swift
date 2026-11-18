import Foundation

/// A parsed HTTP/1.x request head.
struct HTTPRequest: Sendable, Equatable {
    var method: String
    /// Raw request target, e.g. "/s/abc/file/1/a.jpg?x=1".
    var target: String
    var version: String
    /// Header fields in order of appearance; names keep their original case.
    var headers: [(name: String, value: String)]

    /// Percent-decoded path without the query.
    var path: String {
        let rawPath = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? target
        return rawPath.removingPercentEncoding ?? rawPath
    }

    /// Decoded query items (last value wins).
    var query: [String: String] {
        guard let components = URLComponents(string: "http://host" + target) else { return [:] }
        var result: [String: String] = [:]
        for item in components.queryItems ?? [] {
            result[item.name] = item.value ?? ""
        }
        return result
    }

    /// First value of a header, case-insensitive.
    func header(_ name: String) -> String? {
        headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    var contentLength: Int64? {
        header("Content-Length").flatMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
    }

    static func == (lhs: HTTPRequest, rhs: HTTPRequest) -> Bool {
        lhs.method == rhs.method
            && lhs.target == rhs.target
            && lhs.version == rhs.version
            && lhs.headers.map(\.name) == rhs.headers.map(\.name)
            && lhs.headers.map(\.value) == rhs.headers.map(\.value)
    }
}

enum HTTPParseError: Error, Equatable {
    case headTooLarge
    case malformedRequestLine
    case malformedHeader
    case unsupportedVersion
    case invalidContentLength
}

/// Incremental parser of a request head. Feed bytes as they arrive; once the head is complete
/// `append` returns the request and `bodyPrefix` holds any body bytes received with it.
struct HTTPRequestParser: Sendable {
    static let headerTerminator = Data("\r\n\r\n".utf8)

    let maxHeadSize: Int
    private var buffer = Data()
    private(set) var request: HTTPRequest?
    /// Body bytes that arrived together with the head.
    private(set) var bodyPrefix = Data()

    init(maxHeadSize: Int = 16 * 1024) {
        self.maxHeadSize = maxHeadSize
    }

    var isComplete: Bool { request != nil }

    /// Returns the request once the head is complete; nil while more bytes are needed.
    mutating func append(_ data: Data) throws -> HTTPRequest? {
        if request != nil {
            bodyPrefix.append(data)
            return request
        }
        buffer.append(data)
        guard let end = HTTPByteSearch.firstIndex(of: Self.headerTerminator, in: buffer) else {
            if buffer.count > maxHeadSize {
                throw HTTPParseError.headTooLarge
            }
            return nil
        }
        guard end <= maxHeadSize else { throw HTTPParseError.headTooLarge }
        let headData = buffer.prefix(end)
        let parsed = try Self.parseHead(Data(headData))
        bodyPrefix = Data(buffer.suffix(from: buffer.startIndex + end + Self.headerTerminator.count))
        buffer = Data()
        request = parsed
        return parsed
    }

    static func parseHead(_ data: Data) throws -> HTTPRequest {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw HTTPParseError.malformedRequestLine
        }
        var lines = text.components(separatedBy: "\r\n")
        // Tolerate leading empty lines (RFC 9112 §2.2).
        while let first = lines.first, first.isEmpty {
            lines.removeFirst()
        }
        guard let requestLine = lines.first else { throw HTTPParseError.malformedRequestLine }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 3 else { throw HTTPParseError.malformedRequestLine }
        let version = String(parts[2])
        guard version.hasPrefix("HTTP/1.") else { throw HTTPParseError.unsupportedVersion }
        var headers: [(name: String, value: String)] = []
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { throw HTTPParseError.malformedHeader }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !name.contains(" ") else { throw HTTPParseError.malformedHeader }
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers.append((name: name, value: value))
        }
        let request = HTTPRequest(
            method: String(parts[0]).uppercased(),
            target: String(parts[1]),
            version: version,
            headers: headers
        )
        if let raw = request.header("Content-Length"), Int64(raw.trimmingCharacters(in: .whitespaces)) == nil {
            throw HTTPParseError.invalidContentLength
        }
        return request
    }
}

/// Fast byte-pattern search (memmem) on Data.
enum HTTPByteSearch {
    /// Offset (from the start of `data`, not its startIndex) of the first occurrence of `pattern`.
    static func firstIndex(of pattern: Data, in data: Data, from start: Int = 0) -> Int? {
        guard !pattern.isEmpty, data.count - start >= pattern.count, start >= 0 else { return nil }
        return data.withUnsafeBytes { haystack -> Int? in
            pattern.withUnsafeBytes { needle -> Int? in
                guard let base = haystack.baseAddress, let needleBase = needle.baseAddress else { return nil }
                let found = memmem(base + start, haystack.count - start, needleBase, needle.count)
                guard let found else { return nil }
                return base.distance(to: UnsafeRawPointer(found))
            }
        }
    }
}
