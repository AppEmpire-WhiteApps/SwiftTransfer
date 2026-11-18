import SwiftData
import SwiftUI

/// Conversations list with swipe-to-delete. Used in the iPhone sheet and the iPad sidebar.
struct AssistantThreadList: View {
    let threads: [ChatThread]
    let selectedID: UUID?
    var onSelect: (ChatThread) -> Void
    var onDelete: (ChatThread) -> Void

    var body: some View {
        List {
            if threads.isEmpty {
                Text("No chats yet. Ask your first question.")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(threads) { thread in
                Button {
                    onSelect(thread)
                } label: {
                    AssistantThreadRow(thread: thread)
                }
                .buttonStyle(.plain)
                .listRowBackground(thread.id == selectedID ? AppColor.skyLight : AppColor.surface)
                .accessibilityAddTraits(thread.id == selectedID ? .isSelected : [])
            }
            .onDelete { offsets in
                for index in offsets {
                    onDelete(threads[index])
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
    }
}

private struct AssistantThreadRow: View {
    let thread: ChatThread

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.body)
                .foregroundStyle(AppColor.primary)
                .frame(width: 36, height: 36)
                .background(AppColor.skyMist, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                titleText
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)
                Text(thread.updatedAt, format: .relative(presentation: .named))
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var titleText: Text {
        thread.title.isEmpty ? Text("New chat") : Text(verbatim: thread.title)
    }
}

#Preview {
    let container = AssistantPreviewData.container(withConversation: true)
    let threads = (try? container.mainContext.fetch(FetchDescriptor<ChatThread>())) ?? []
    return NavigationStack {
        AssistantThreadList(threads: threads, selectedID: threads.first?.id, onSelect: { _ in }, onDelete: { _ in })
            .navigationTitle("Chats")
    }
    .modelContainer(container)
}
