import Foundation

enum MultipartError: Error, Equatable {
    case missingBoundary
    case malformedPartHeaders
    case partHeadersTooLarge
}

/// Header block of one multipart/form-data part.
struct MultipartPartInfo: Sendable, Equatable {
    var headers: [String: String]
    var name: String?
    var filename: String?
    var contentType: String?
}

enum MultipartEvent: Sendable, Equatable {
    case partBegin(MultipartPartInfo)
    case partData(Data)
    case partEnd
    case finished
}

/// Streaming multipart/form-data parser. Feed body chunks; it emits part events and body slices
/// without ever buffering a whole part, so uploads can be written straight to disk.
struct MultipartParser: Sendable {
    private enum State {
        case preamble
        case afterDelimiter
        case headers
        case body
        case epilogue
    }

    let boundary: String
    private let delimiter: Data
    private let maxHeaderSize = 16 * 1024
    private var buffer: Data
    private var state: State = .preamble

    init(boundary: String) {
        self.boundary = boundary
        self.delimiter = Data("\r\n--\(boundary)".utf8)
        // A leading CRLF lets the first boundary match the same delimiter as the following ones.
        self.buffer = Data("\r\n".utf8)
    }

    /// Creates a parser from a `Content-Type: multipart/form-data; boundary=...` value.
    init(contentType: String) throws {
        guard let boundary = MultipartParser.boundary(fromContentType: contentType) else {
            throw MultipartError.missingBoundary
        }
        self.init(boundary: boundary)
    }

    var isFinished: Bool { state == .epilogue }

    static func boundary(fromContentType contentType: String) -> String? {
        let parameters = HTTPHeaderParameters.parse(contentType)
        guard parameters.value.lowercased().hasPrefix("multipart/"),
              let boundary = parameters.parameters["boundary"], !boundary.isEmpty
        else { return nil }
        return boundary
    }

    mutating func feed(_ data: Data) throws -> [MultipartEvent] {
        if state == .epilogue {
            return []
        }
        buffer.append(data)
        var events: [MultipartEvent] = []
        var progressed = true
        while progressed {
            progressed = false
            switch state {
            case .preamble:
                if let index = HTTPByteSearch.firstIndex(of: delimiter, in: buffer) {
                    consume(index + delimiter.count)
                    state = .afterDelimiter
                    progressed = true
                } else {
                    keepTail()
                }
            case .afterDelimiter:
                guard buffer.count >= 2 else { break }
                let first = buffer[buffer.startIndex]
                let second = buffer[buffer.startIndex + 1]
                if first == UInt8(ascii: "-"), second == UInt8(ascii: "-") {
                    state = .epilogue
                    buffer = Data()
                    events.append(.finished)
                } else if first == UInt8(ascii: "\r"), second == UInt8(ascii: "\n") {
                    consume(2)
                    state = .headers
                    progressed = true
                } else if first == UInt8(ascii: " ") || first == UInt8(ascii: "\t") {
                    // Transport padding after the boundary.
                    consume(1)
                    progressed = true
                } else {
                    throw MultipartError.malformedPartHeaders
                }
            case .headers:
                if buffer.starts(with: Data("\r\n".utf8)) {
                    // Part without headers.
                    consume(2)
                    events.append(.partBegin(MultipartPartInfo(headers: [:])))
                    state = .body
                    progressed = true
                } else if let end = HTTPByteSearch.firstIndex(of: HTTPRequestParser.headerTerminator, in: buffer) {
                    let headerData = Data(buffer.prefix(end))
                    consume(end + HTTPRequestParser.headerTerminator.count)
                    events.append(.partBegin(try Self.parsePartHeaders(headerData)))
                    state = .body
                    progressed = true
                } else if buffer.count > maxHeaderSize {
                    throw MultipartError.partHeadersTooLarge
                }
            case .body:
                if let index = HTTPByteSearch.firstIndex(of: delimiter, in: buffer) {
                    if index > 0 {
                        events.append(.partData(Data(buffer.prefix(index))))
                    }
                    events.append(.partEnd)
                    consume(index + delimiter.count)
                    state = .afterDelimiter
                    progressed = true
                } else {
                    let safeCount = buffer.count - (delimiter.count - 1)
                    if safeCount > 0 {
                        events.append(.partData(Data(buffer.prefix(safeCount))))
                        consume(safeCount)
                    }
                }
            case .epilogue:
                break
            }
        }
        return events
    }

    private mutating func consume(_ count: Int) {
        buffer = Data(buffer.dropFirst(count))
    }

    private mutating func keepTail() {
        let keep = delimiter.count - 1
        if buffer.count > keep {
            buffer = Data(buffer.suffix(keep))
        }
    }

    static func parsePartHeaders(_ data: Data) throws -> MultipartPartInfo {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw MultipartError.malformedPartHeaders
        }
        var headers: [String: String] = [:]
        for line in text.components(separatedBy: "\r\n") where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { throw MultipartError.malformedPartHeaders }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        var info = MultipartPartInfo(headers: headers, contentType: headers["content-type"])
        if let disposition = headers["content-disposition"] {
            let parsed = HTTPHeaderParameters.parse(disposition)
            info.name = parsed.parameters["name"]
            if let extended = parsed.parameters["filename*"], let decoded = HTTPHeaderParameters.decodeRFC5987(extended) {
                info.filename = decoded
            } else {
                info.filename = parsed.parameters["filename"]
            }
        }
        return info
    }
}

/// Parser for header values with parameters: `value; a=b; c="d e"`.
enum HTTPHeaderParameters {
    static func parse(_ header: String) -> (value: String, parameters: [String: String]) {
        var parameters: [String: String] = [:]
        var segments: [String] = []
        var current = ""
        var inQuotes = false
        var escaped = false
        for character in header {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" && inQuotes {
                escaped = true
                continue
            }
            if character == "\"" {
                inQuotes.toggle()
                continue
            }
            if character == ";" && !inQuotes {
                segments.append(current)
                current = ""
                continue
            }
            current.append(character)
        }
        segments.append(current)
        let value = segments.first?.trimmingCharacters(in: .whitespaces) ?? ""
        for segment in segments.dropFirst() {
            guard let equals = segment.firstIndex(of: "=") else { continue }
            let key = segment[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            let rawValue = segment[segment.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            parameters[key] = rawValue
        }
        return (value, parameters)
    }

    /// Decodes `UTF-8''na%C3%AFve.txt`.
    static func decodeRFC5987(_ value: String) -> String? {
        let parts = value.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        return String(parts[2]).removingPercentEncoding
    }
}
