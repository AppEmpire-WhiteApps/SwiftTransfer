import Foundation

/// A block of assistant Markdown.
enum ChatMarkdownBlock: Equatable, Sendable {
    case paragraph(String)
    case heading(String)
    case bulletList([String])
    case numberedList(start: Int, items: [String])
}

/// Lightweight Markdown block parser for assistant replies (TZ §7.6).
///
/// Supports paragraphs, headings, bulleted (`-`, `*`, `+`, `•`) and numbered (`1.`, `1)`) lists.
/// Inline styles (bold, italic, links, code) are rendered by `AttributedString(markdown:)`.
/// Code fences are dropped, their content is kept as text.
enum ChatMarkdownParser {
    static func parse(_ markdown: String) -> [ChatMarkdownBlock] {
        var builder = BlockBuilder()
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                builder.flush()
            } else if line.hasPrefix("```") {
                continue
            } else if let heading = headingText(line) {
                builder.flush()
                builder.blocks.append(.heading(heading))
            } else if let item = bulletItem(line) {
                builder.addBullet(item)
            } else if case let (number, item)? = numberedItem(line) {
                builder.addNumbered(number, item)
            } else if builder.hasOpenList, rawLine.first?.isWhitespace == true {
                builder.continueListItem(line)
            } else {
                builder.addParagraphLine(line)
            }
        }
        builder.flush()
        return builder.blocks
    }

    /// Inline Markdown (bold, italic, links, code spans) as an attributed string.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private static func headingText(_ line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else {
            return nil
        }
        let rest = line.dropFirst(hashes.count)
        guard rest.first == " " else {
            return nil
        }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    private static func bulletItem(_ line: String) -> String? {
        guard let marker = line.first, "-*+•".contains(marker) else {
            return nil
        }
        let rest = line.dropFirst()
        guard rest.first == " " else {
            return nil
        }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    private static func numberedItem(_ line: String) -> (Int, String)? {
        let digits = line.prefix { $0.isASCII && $0.isNumber }
        guard (1...3).contains(digits.count), let number = Int(digits) else {
            return nil
        }
        let rest = line.dropFirst(digits.count)
        guard let marker = rest.first, marker == "." || marker == ")" else {
            return nil
        }
        let afterMarker = rest.dropFirst()
        guard afterMarker.first == " " else {
            return nil
        }
        let text = afterMarker.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (number, text)
    }
}

private struct BlockBuilder {
    private enum OpenBlock {
        case none
        case paragraph([String])
        case bullets([String])
        case numbers(start: Int, items: [String])
    }

    var blocks: [ChatMarkdownBlock] = []
    private var open = OpenBlock.none

    var hasOpenList: Bool {
        switch open {
        case .bullets, .numbers: true
        default: false
        }
    }

    mutating func addParagraphLine(_ line: String) {
        if case .paragraph(let lines) = open {
            open = .paragraph(lines + [line])
        } else {
            flush()
            open = .paragraph([line])
        }
    }

    mutating func addBullet(_ item: String) {
        if case .bullets(let items) = open {
            open = .bullets(items + [item])
        } else {
            flush()
            open = .bullets([item])
        }
    }

    mutating func addNumbered(_ number: Int, _ item: String) {
        if case .numbers(let start, let items) = open {
            open = .numbers(start: start, items: items + [item])
        } else {
            flush()
            open = .numbers(start: number, items: [item])
        }
    }

    mutating func continueListItem(_ line: String) {
        switch open {
        case .bullets(var items):
            items[items.count - 1] += "\n" + line
            open = .bullets(items)
        case .numbers(let start, var items):
            items[items.count - 1] += "\n" + line
            open = .numbers(start: start, items: items)
        default:
            addParagraphLine(line)
        }
    }

    mutating func flush() {
        switch open {
        case .none:
            break
        case .paragraph(let lines):
            blocks.append(.paragraph(lines.joined(separator: "\n")))
        case .bullets(let items):
            blocks.append(.bulletList(items))
        case .numbers(let start, let items):
            blocks.append(.numberedList(start: start, items: items))
        }
        open = .none
    }
}
