import Foundation

/// Turns JSON failures into readable messages: the failing field path, or the syntax error
/// position with a fragment of the source where invisible characters are made visible.
enum JSONDiagnostics {
    struct Report {
        let message: String
        let fragment: String?
    }

    private static let fragmentRadius = 40
    private static let fragmentMarker = "👉"

    /// Valid in JSON, but usually pasted by accident: they break lines or hide inside texts.
    private static let suspiciousScalars: [UInt32: String] = [
        0x2028: "U+2028 LINE SEPARATOR",
        0x2029: "U+2029 PARAGRAPH SEPARATOR",
        0xFEFF: "U+FEFF BYTE ORDER MARK",
        0x200B: "U+200B ZERO WIDTH SPACE"
    ]

    static func describe(_ error: Error, in data: Data) -> Report {
        switch error {
        case DecodingError.keyNotFound(let key, let context):
            return Report(message: "missing key \(path(context.codingPath + [key]))", fragment: nil)
        case DecodingError.typeMismatch(let type, let context):
            return Report(
                message: "\(path(context.codingPath)) has a wrong type, expected \(type) — \(context.debugDescription)",
                fragment: nil
            )
        case DecodingError.valueNotFound(let type, let context):
            return Report(message: "\(path(context.codingPath)) is null, expected \(type)", fragment: nil)
        case DecodingError.dataCorrupted(let context):
            if let underlying = context.underlyingError {
                return syntaxReport(underlying as NSError, in: data)
            }
            return Report(message: "\(path(context.codingPath)): \(context.debugDescription)", fragment: nil)
        default:
            return syntaxReport(error as NSError, in: data)
        }
    }

    /// Reports suspicious invisible characters even when the JSON itself is valid.
    static func suspiciousCharacters(in data: Data) -> Report? {
        let text = String(decoding: data, as: UTF8.self)
        var counts: [String: Int] = [:]
        var firstOffset: Int?
        var byteOffset = 0

        for scalar in text.unicodeScalars {
            if let name = suspiciousScalars[scalar.value] {
                counts[name, default: 0] += 1
                if firstOffset == nil {
                    firstOffset = byteOffset
                }
            }
            byteOffset += UTF8.width(scalar)
        }

        guard let firstOffset else { return nil }

        let list = counts
            .sorted { $0.key < $1.key }
            .map { "\($0.key) ×\($0.value)" }
            .joined(separator: ", ")
        return Report(
            message: "contains invisible characters: \(list)",
            fragment: fragment(in: data, at: firstOffset)
        )
    }

    private static func syntaxReport(_ error: NSError, in data: Data) -> Report {
        let description = error.userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
        var message = "invalid JSON — \(description)"
        if description.localizedCaseInsensitiveContains("control character") {
            message += " (a raw line break or tab inside a string: it must be escaped as \\n or \\t)"
        }

        let offset = error.userInfo["NSJSONSerializationErrorIndex"] as? Int
            ?? offset(fromLineAndColumnIn: description, data: data)
        return Report(message: message, fragment: offset.map { fragment(in: data, at: $0) })
    }

    private static func path(_ codingPath: [CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "root" }

        var result = ""
        for key in codingPath {
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                result += result.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return result
    }

    /// Parses "line N, column M" from the parser message into a byte offset.
    private static func offset(fromLineAndColumnIn description: String, data: Data) -> Int? {
        guard
            let regex = try? NSRegularExpression(pattern: #"line (\d+), column (\d+)"#),
            let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
            let lineRange = Range(match.range(at: 1), in: description),
            let columnRange = Range(match.range(at: 2), in: description),
            let line = Int(description[lineRange]),
            let column = Int(description[columnRange])
        else { return nil }

        var currentLine = 1
        var lineStart = 0
        for (index, byte) in data.enumerated() where currentLine < line {
            if byte == 0x0A {
                currentLine += 1
                lineStart = index + 1
            }
        }
        return min(lineStart + max(column - 1, 0), data.count)
    }

    private static func fragment(in data: Data, at offset: Int) -> String {
        let bytes = [UInt8](data)
        let position = scalarBoundary(in: bytes, from: min(max(offset, 0), bytes.count))
        let start = scalarBoundary(in: bytes, from: max(0, position - fragmentRadius))
        let end = scalarBoundary(in: bytes, from: min(bytes.count, position + fragmentRadius))

        let before = visible(String(decoding: bytes[start..<position], as: UTF8.self))
        let after = visible(String(decoding: bytes[position..<end], as: UTF8.self))
        return "…\(before)\(fragmentMarker)\(after)…"
    }

    /// Moves forward past UTF-8 continuation bytes so a fragment never starts mid-character.
    private static func scalarBoundary(in bytes: [UInt8], from index: Int) -> Int {
        var index = index
        while index < bytes.count, bytes[index] & 0xC0 == 0x80 {
            index += 1
        }
        return index
    }

    /// Raw control characters are shown as <LF>/<CR>/<TAB> so they differ from the escapes \n, \r, \t.
    private static func visible(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0A:
                result += "<LF>"
            case 0x0D:
                result += "<CR>"
            case 0x09:
                result += "<TAB>"
            case 0x00..<0x20, 0x7F, 0x00A0, 0x200B, 0x2028, 0x2029, 0xFEFF:
                result += String(format: "<U+%04X>", scalar.value)
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}
