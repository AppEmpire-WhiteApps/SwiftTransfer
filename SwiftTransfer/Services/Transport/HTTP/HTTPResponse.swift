import Foundation

/// HTTP/1.1 response head. Connections are never kept alive (`Connection: close`).
struct HTTPResponseHead: Sendable {
    var status: Int
    var headers: [(name: String, value: String)] = []

    init(status: Int, headers: [(name: String, value: String)] = []) {
        self.status = status
        self.headers = headers
    }

    mutating func setHeader(_ name: String, _ value: String) {
        headers.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        headers.append((name: name, value: value))
    }

    func header(_ name: String) -> String? {
        headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    func serialized() -> Data {
        var lines = ["HTTP/1.1 \(status) \(HTTPResponseHead.reasonPhrase(for: status))"]
        var hasConnection = false
        for header in headers {
            if header.name.caseInsensitiveCompare("Connection") == .orderedSame {
                hasConnection = true
                lines.append("Connection: close")
            } else {
                lines.append("\(header.name): \(HTTPResponseHead.sanitize(header.value))")
            }
        }
        if !hasConnection {
            lines.append("Connection: close")
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
    }

    /// Strips CR/LF to prevent header injection.
    private static func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
    }

    static func reasonPhrase(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 204: "No Content"
        case 206: "Partial Content"
        case 302: "Found"
        case 304: "Not Modified"
        case 400: "Bad Request"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 408: "Request Timeout"
        case 410: "Gone"
        case 413: "Content Too Large"
        case 416: "Range Not Satisfiable"
        case 429: "Too Many Requests"
        case 500: "Internal Server Error"
        case 503: "Service Unavailable"
        case 507: "Insufficient Storage"
        default: "Status"
        }
    }

    // MARK: - Builders

    static func data(status: Int = 200, contentType: String, length: Int) -> HTTPResponseHead {
        var head = HTTPResponseHead(status: status)
        head.setHeader("Content-Type", contentType)
        head.setHeader("Content-Length", String(length))
        head.setHeader("Cache-Control", "no-store")
        head.setHeader("X-Content-Type-Options", "nosniff")
        return head
    }

    /// Head for a file download honouring a Range decision.
    static func download(
        filename: String,
        contentType: String,
        size: Int64?,
        decision: RangeDecision
    ) -> HTTPResponseHead {
        var head: HTTPResponseHead
        switch decision {
        case .unsatisfiable:
            head = HTTPResponseHead(status: 416)
            head.setHeader("Content-Range", "bytes */\(size ?? 0)")
            head.setHeader("Content-Length", "0")
            return head
        case .partial(let range):
            head = HTTPResponseHead(status: 206)
            head.setHeader("Content-Range", "bytes \(range.lowerBound)-\(range.upperBound)/\(size ?? 0)")
            head.setHeader("Content-Length", String(range.upperBound - range.lowerBound + 1))
        case .full:
            head = HTTPResponseHead(status: 200)
            if let size {
                head.setHeader("Content-Length", String(size))
            }
        }
        head.setHeader("Content-Type", contentType)
        head.setHeader("Content-Disposition", contentDisposition(filename: filename))
        head.setHeader("Accept-Ranges", size == nil ? "none" : "bytes")
        head.setHeader("Cache-Control", "no-store")
        head.setHeader("X-Content-Type-Options", "nosniff")
        return head
    }

    /// `attachment; filename="ascii"; filename*=UTF-8''percent-encoded` (RFC 6266 / RFC 5987).
    static func contentDisposition(filename: String, disposition: String = "attachment") -> String {
        let fallback = asciiFallback(filename)
        let encoded = rfc5987Encode(filename)
        return "\(disposition); filename=\"\(fallback)\"; filename*=UTF-8''\(encoded)"
    }

    static func asciiFallback(_ filename: String) -> String {
        var result = ""
        for scalar in filename.unicodeScalars {
            if scalar.isASCII, scalar.value >= 0x20, scalar != "\"", scalar != "\\", scalar.value != 0x7F {
                result.unicodeScalars.append(scalar)
            } else {
                result.append("_")
            }
        }
        return result.isEmpty ? "file" : result
    }

    static func rfc5987Encode(_ value: String) -> String {
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$&+-.^_`|~"
        )
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "file"
    }

    static func contentType(forFilename name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js": return "text/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "txt": return "text/plain; charset=utf-8"
        case "vcf": return "text/vcard; charset=utf-8"
        case "ics": return "text/calendar; charset=utf-8"
        case "zip": return "application/zip"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "heic": return "image/heic"
        case "heif": return "image/heif"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mov": return "video/quicktime"
        case "mp4", "m4v": return "video/mp4"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}
