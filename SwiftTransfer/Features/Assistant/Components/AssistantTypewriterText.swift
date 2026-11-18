import SwiftUI

/// Reveals an assistant reply word by word, as if it is being typed.
///
/// The bubble grows with the typed text; `onProgress` is called after each step so the chat
/// can keep the end of the text in view.
/// Unfinished Markdown markers are closed on the fly so raw `**` or half-typed links never flash.
/// Tapping the bubble shows the whole reply at once. With Reduce Motion it appears immediately.
struct AssistantTypewriterText: View {
    let text: String
    var onProgress: () -> Void = {}
    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleCount = 0

    private static let tick: Duration = .milliseconds(40)
    /// Long replies speed up so typing takes at most about this many ticks (~4 s).
    private static let maxTicks = 100

    var body: some View {
        AssistantMarkdownText(TypewriterMarkdown.partial(text, count: visibleCount), cached: false)
            .contentShape(Rectangle())
            .onTapGesture {
                visibleCount = text.count
            }
            .onChange(of: visibleCount) {
                onProgress()
            }
            .task(id: text) {
                await type()
            }
    }

    private func type() async {
        let stops = TypewriterMarkdown.wordEnds(in: text)
        if reduceMotion {
            visibleCount = text.count
        }
        let wordsPerTick = max(1, Int((Double(stops.count) / Double(Self.maxTicks)).rounded(.up)))
        var index = -1
        while visibleCount < text.count, index < stops.count - 1 {
            do {
                try await Task.sleep(for: Self.tick)
            } catch {
                return
            }
            index = min(stops.count - 1, index + wordsPerTick)
            visibleCount = max(visibleCount, stops[index])
        }
        visibleCount = text.count
        onFinish()
    }
}

/// Builds a renderable Markdown prefix of a reply that is still being typed.
enum TypewriterMarkdown {
    /// Character counts at the end of each word (and of the whole text), used as typing steps.
    static func wordEnds(in text: String) -> [Int] {
        var stops: [Int] = []
        var count = 0
        var previousIsSpace = true
        for character in text {
            let isSpace = character.isWhitespace
            if isSpace, !previousIsSpace {
                stops.append(count)
            }
            previousIsSpace = isSpace
            count += 1
        }
        if stops.last != count {
            stops.append(count)
        }
        return stops
    }

    static func partial(_ text: String, count: Int) -> String {
        guard count < text.count else {
            return text
        }
        var prefix = String(text.prefix(max(0, count)))

        // An unfinished link "[title](url" is hidden until it is complete.
        if let open = prefix.lastIndex(of: "["), !prefix[open...].contains(")") {
            prefix = String(prefix[..<open])
        }
        // Trailing whitespace would stop a closing marker from working; a trailing "*" may be half a marker.
        while let last = prefix.last, last.isWhitespace || last == "*" {
            prefix.removeLast()
        }

        // Emphasis never spans lines, so only the last line can have an open marker.
        let lastLine = prefix.split(separator: "\n", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        let body = lineBodyWithoutBullet(lastLine)
        let boldMarkers = body.components(separatedBy: "**").count - 1
        let italicMarkers = body.replacingOccurrences(of: "**", with: "").filter { $0 == "*" }.count
        if italicMarkers % 2 == 1 {
            prefix += "*"
        }
        if boldMarkers % 2 == 1 {
            prefix += "**"
        }
        return prefix
    }

    /// The line without a leading "* " bullet, whose asterisk is not emphasis.
    private static func lineBodyWithoutBullet(_ line: String) -> String {
        let trimmed = line.drop { $0 == " " }
        if trimmed.hasPrefix("* ") {
            return String(trimmed.dropFirst(2))
        }
        return line
    }
}

#Preview {
    AssistantTypewriterText(
        text: "Here's how to move **photos** to Android:\n\n1. Connect both phones to the *same Wi-Fi*.\n2. Tap **Send data** and choose Android.\n3. Scan the QR code."
    )
    .padding()
    .background(AppColor.skyMist)
    .padding()
}
