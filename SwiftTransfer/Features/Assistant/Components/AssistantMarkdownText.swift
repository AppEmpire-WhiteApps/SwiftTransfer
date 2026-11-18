import SwiftUI

/// A Markdown block with its inline styles already rendered.
enum RenderedMarkdownBlock {
    case paragraph(AttributedString)
    case heading(AttributedString)
    case bulletList([AttributedString])
    case numberedList(start: Int, items: [AttributedString])

    static func render(_ markdown: String) -> [RenderedMarkdownBlock] {
        ChatMarkdownParser.parse(markdown).map { block in
            switch block {
            case .paragraph(let text):
                .paragraph(ChatMarkdownParser.inline(text))
            case .heading(let text):
                .heading(ChatMarkdownParser.inline(text))
            case .bulletList(let items):
                .bulletList(items.map(ChatMarkdownParser.inline))
            case .numberedList(let start, let items):
                .numberedList(start: start, items: items.map(ChatMarkdownParser.inline))
            }
        }
    }
}

/// Keeps rendered Markdown of finished messages so redraws don't parse it again.
@MainActor
enum MarkdownRenderCache {
    private static var storage: [String: [RenderedMarkdownBlock]] = [:]
    private static let limit = 300

    static func blocks(for markdown: String) -> [RenderedMarkdownBlock] {
        if let cached = storage[markdown] {
            return cached
        }
        let blocks = RenderedMarkdownBlock.render(markdown)
        if storage.count >= limit {
            storage.removeAll(keepingCapacity: true)
        }
        storage[markdown] = blocks
        return blocks
    }
}

/// Renders assistant Markdown: paragraphs, headings, numbered and bulleted lists, inline bold/italic/links.
struct AssistantMarkdownText: View {
    private let blocks: [RenderedMarkdownBlock]

    /// - Parameter cached: Pass false for text that changes often (a reply being typed).
    init(_ markdown: String, cached: Bool = true) {
        blocks = cached ? MarkdownRenderCache.blocks(for: markdown) : RenderedMarkdownBlock.render(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .font(AppFont.body)
        .foregroundStyle(AppColor.textPrimary)
        .tint(AppColor.primary)
    }

    @ViewBuilder
    private func blockView(_ block: RenderedMarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            inlineText(text)
        case .heading(let text):
            inlineText(text)
                .font(AppFont.headline)
                .accessibilityAddTraits(.isHeader)
        case .bulletList(let items):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    listRow(marker: "•", text: item)
                }
            }
        case .numberedList(let start, let items):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    listRow(marker: "\(start + index).", text: item)
                }
            }
        }
    }

    private func listRow(marker: String, text: AttributedString) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(verbatim: marker)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(AppColor.primary)
            inlineText(text)
        }
    }

    private func inlineText(_ text: AttributedString) -> some View {
        Text(text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AssistantMarkdownText(
        """
        Here's how to move **photos** to Android:

        1. Connect both phones to the *same Wi-Fi*.
        2. Tap **Send data** and choose Android.
        3. Scan the QR code.

        - Originals stay on your iPhone
        - No app is needed on Android

        More in the [Help Center](https://example.com).
        """
    )
    .padding()
    .background(AppColor.skyMist)
}
