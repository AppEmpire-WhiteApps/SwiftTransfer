import SwiftData
import SwiftUI

/// The Assistant tab. iPhone: the latest conversation with a chats list in a sheet.
/// iPad (regular width): a split view with the chats list and the conversation.
struct AssistantTabView: View {
    @Environment(\.assistantClient) private var client
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if let client {
                AssistantConversationsView(client: client)
            } else {
                NavigationStack {
                    AssistantUnavailableView {
                        router.selectedTab = .guides
                    }
                    .navigationTitle("Assistant")
                }
            }
        }
        .trackScreen("assistant")
    }
}

private struct AssistantConversationsView: View {
    let client: any LLMClienting

    @Query(sort: \ChatThread.updatedAt, order: .reverse) private var threads: [ChatThread]
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var session = AssistantChatSession(threadID: nil)
    @State private var didRestoreLatest = false
    @State private var showsThreadList = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitLayout
            } else {
                compactLayout
            }
        }
        .onAppear(perform: restoreLatestThread)
        .onChange(of: threads.map(\.id)) { _, ids in
            if let id = session.threadID, !ids.contains(id) {
                session = AssistantChatSession(threadID: nil)
            }
        }
    }

    private var currentThread: ChatThread? {
        guard let id = session.threadID else {
            return nil
        }
        return threads.first { $0.id == id }
    }

    private var chatTitle: Text {
        if let title = currentThread?.title, !title.isEmpty {
            Text(verbatim: title)
        } else {
            Text("Assistant")
        }
    }

    private var chat: some View {
        AssistantChatScreen(
            thread: currentThread,
            client: client,
            onThreadCreated: { thread in
                session.threadID = thread.id
            },
            onAction: { action in
                router.perform(action)
            }
        )
        .id(session.id)
    }

    // MARK: - iPhone

    private var compactLayout: some View {
        NavigationStack {
            chat
                .navigationTitle(chatTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showsThreadList = true
                        } label: {
                            Label("Chats", systemImage: "list.bullet")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        newChatButton
                    }
                }
        }
        .sheet(isPresented: $showsThreadList) {
            NavigationStack {
                AssistantThreadList(
                    threads: threads,
                    selectedID: session.threadID,
                    onSelect: { thread in
                        open(thread)
                        showsThreadList = false
                    },
                    onDelete: delete
                )
                .navigationTitle("Chats")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showsThreadList = false
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            startNewChat()
                            showsThreadList = false
                        } label: {
                            Label("New chat", systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - iPad

    private var splitLayout: some View {
        NavigationSplitView {
            AssistantThreadList(
                threads: threads,
                selectedID: session.threadID,
                onSelect: open,
                onDelete: delete
            )
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    newChatButton
                }
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 400)
        } detail: {
            NavigationStack {
                chat
                    .navigationTitle(chatTitle)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var newChatButton: some View {
        Button {
            startNewChat()
        } label: {
            Label("New chat", systemImage: "square.and.pencil")
        }
    }

    // MARK: - Actions

    private func restoreLatestThread() {
        guard !didRestoreLatest else {
            return
        }
        didRestoreLatest = true
        if let latest = threads.first {
            session = AssistantChatSession(threadID: latest.id)
        }
    }

    private func open(_ thread: ChatThread) {
        guard thread.id != session.threadID else {
            return
        }
        session = AssistantChatSession(threadID: thread.id)
    }

    private func startNewChat() {
        guard session.threadID != nil else {
            return
        }
        session = AssistantChatSession(threadID: nil)
    }

    private func delete(_ thread: ChatThread) {
        if thread.id == session.threadID {
            session = AssistantChatSession(threadID: nil)
        }
        modelContext.delete(thread)
        try? modelContext.save()
    }
}

/// The assistant in a sheet, opened from other screens via `AppRouter.askAssistant(draft:)`.
/// Starts a new conversation with the draft pre-filled into the input (not sent automatically).
struct AssistantSheetView: View {
    let launch: AssistantLaunch

    @Environment(\.assistantClient) private var client
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            Group {
                if let client {
                    AssistantChatScreen(
                        thread: nil,
                        client: client,
                        draft: launch.draft,
                        stopsOnDisappear: true,
                        onAction: { action in
                            dismiss()
                            router.perform(action)
                        }
                    )
                } else {
                    AssistantUnavailableView {
                        dismiss()
                        router.selectedTab = .guides
                    }
                }
            }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .premiumPresentation()
    }
}

#Preview("Tab") {
    AssistantTabView()
        .modelContainer(AssistantPreviewData.container(withConversation: true))
        .environment(AppRouter())
        .environment(AppActivityContext())
        .environment(\.assistantClient, MockLLMClient())
}

#Preview("Sheet") {
    AssistantSheetView(launch: AssistantLaunch(draft: "The transfer stopped with \"Connection lost\". What should I do?"))
        .modelContainer(AssistantPreviewData.container(withConversation: false))
        .environment(AppRouter())
        .environment(AppActivityContext())
        .environment(\.assistantClient, MockLLMClient())
}

#Preview("Unavailable") {
    AssistantTabView()
        .modelContainer(AssistantPreviewData.container(withConversation: false))
        .environment(AppRouter())
        .environment(AppActivityContext())
        .environment(\.assistantClient, nil)
}
