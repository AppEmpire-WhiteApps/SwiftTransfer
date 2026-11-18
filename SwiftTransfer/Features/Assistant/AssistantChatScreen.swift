import SwiftData
import SwiftUI

/// One assistant conversation: messages, typing indicator and the input bar.
struct AssistantChatScreen: View {
    @State private var viewModel: ChatViewModel
    private let onAction: (AssistantAction) -> Void
    private let stopsOnDisappear: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(AppActivityContext.self) private var activity
    @Environment(AppRouter.self) private var router

    private static let bottomID = "assistant.bottom"

    /// - Parameters:
    ///   - thread: The conversation to show, or nil for a new chat (created with the first question).
    ///   - draft: Text pre-filled into the input (not sent automatically).
    ///   - stopsOnDisappear: Stop a pending request when the screen closes (used by the sheet).
    init(
        thread: ChatThread?,
        client: (any LLMClienting)?,
        draft: String? = nil,
        stopsOnDisappear: Bool = false,
        onThreadCreated: @escaping (ChatThread) -> Void = { _ in },
        onAction: @escaping (AssistantAction) -> Void
    ) {
        let viewModel = ChatViewModel(thread: thread, client: client, draft: draft)
        viewModel.onThreadCreated = onThreadCreated
        _viewModel = State(initialValue: viewModel)
        self.onAction = onAction
        self.stopsOnDisappear = stopsOnDisappear
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.l) {
                    if viewModel.messages.isEmpty {
                        AssistantWelcomeView { question in
                            viewModel.send(question)
                        }
                    } else {
                        AssistantDisclaimer()
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.s)
                    }
                    ForEach(viewModel.messages) { message in
                        AssistantMessageRow(
                            message: message,
                            isTyping: viewModel.typingMessageID == message.id,
                            onRetry: { viewModel.retry(message) },
                            onAction: onAction,
                            onTypingProgress: {
                                proxy.scrollTo(Self.bottomID, anchor: .bottom)
                            },
                            onTypingFinished: viewModel.finishTyping
                        )
                        .id(message.id)
                    }
                    if viewModel.isWaiting {
                        HStack(alignment: .bottom, spacing: Spacing.s) {
                            AssistantAvatar()
                            AssistantTypingIndicator()
                            Spacer()
                        }
                        .transition(.opacity)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomID)
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .pageMargins()
                .padding(.vertical, Spacing.m)
            }
            .modifier(InitialScrollAnchor(anchor: viewModel.messages.isEmpty ? .top : .bottom))
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isWaiting) { _, isWaiting in
                if isWaiting {
                    scrollToBottom(proxy)
                }
            }
            .onChange(of: viewModel.typingMessageID) { _, typingID in
                // Action chips appear when typing ends; keep them in view.
                if typingID == nil {
                    scrollToBottom(proxy)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AssistantChatInputSection(viewModel: viewModel)
        }
        .screenBackground()
        .onAppear {
            viewModel.premiumAccess = router.premiumAccess
            viewModel.attach(modelContext: modelContext, activity: activity)
            viewModel.presentConsentIfNeeded()
        }
        .alert(
            Text("AI Data Processing", tableName: "AssistantConsent"),
            isPresented: $viewModel.isConsentPresented
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") {
                viewModel.approveConsent()
            }
        } message: {
            Text(
                "SwiftTransfer sends your messages, relevant chat history, and optional technical context to LLMApps to provide AI replies. By tapping Continue, you consent to sharing this data with LLMApps.",
                tableName: "AssistantConsent"
            )
        }
        .onDisappear {
            viewModel.finishTyping()
            if stopsOnDisappear {
                viewModel.stop()
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(Self.bottomID, anchor: .bottom)
        }
    }
}

/// Opens the chat at the given anchor without re-anchoring when content grows,
/// so a new reply doesn't push the view around (iOS 18 applies the plain anchor to size changes too).
private struct InitialScrollAnchor: ViewModifier {
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.defaultScrollAnchor(anchor, for: .initialOffset)
        } else {
            content.defaultScrollAnchor(anchor)
        }
    }
}

/// The input bar in its own view, so typing in the field doesn't redraw the message list.
private struct AssistantChatInputSection: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        AssistantInputBar(
            text: $viewModel.input,
            isWaiting: viewModel.isBusy,
            canSend: viewModel.canSend,
            onSend: viewModel.sendInput,
            onStop: viewModel.stop
        )
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .pageMargins()
        .background {
            AppColor.surface
                .opacity(0.94)
                .overlay(alignment: .top) {
                    AppColor.divider.frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .onChange(of: viewModel.input) {
            viewModel.clampInput()
        }
    }
}

/// Sample data for assistant previews.
@MainActor
enum AssistantPreviewData {
    static func container(withConversation: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: ChatThread.self, ChatMessage.self, configurations: configuration)
        if withConversation {
            container.mainContext.insert(sampleThread())
        }
        return container
    }

    static func sampleThread() -> ChatThread {
        let thread = ChatThread(title: "How do I move photos to Android?")
        let question = ChatMessage(
            role: ChatMessage.userRole, text: "How do I move photos to Android?")
        let reply = MockLLMClient.reply(for: question.text)
        let answer = ChatMessage(
            role: ChatMessage.assistantRole,
            text: reply.text,
            actions: reply.actions.map(\.rawValue)
        )
        answer.createdAt = question.createdAt.addingTimeInterval(1)
        thread.messages = [question, answer]
        return thread
    }
}

#Preview("Conversation") {
    let container = AssistantPreviewData.container(withConversation: true)
    let thread = try? container.mainContext.fetch(FetchDescriptor<ChatThread>()).first
    return NavigationStack {
        AssistantChatScreen(thread: thread, client: MockLLMClient()) { _ in }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
    }
    .modelContainer(container)
    .environment(AppActivityContext())
    .environment(AppRouter())
}

#Preview("New chat") {
    NavigationStack {
        AssistantChatScreen(
            thread: nil, client: MockLLMClient(), draft: "The transfer stopped. What should I do?"
        ) { _ in }
    }
    .modelContainer(AssistantPreviewData.container(withConversation: false))
    .environment(AppActivityContext())
    .environment(AppRouter())
}
