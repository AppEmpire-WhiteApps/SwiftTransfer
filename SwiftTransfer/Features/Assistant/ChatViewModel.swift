import Foundation
import Observation
import SwiftData

/// State and actions of one assistant conversation.
///
/// The thread is created lazily with the first question. Messages persist in SwiftData;
/// a failed request keeps the question in the chat with an error and a Retry button.
@MainActor
@Observable
final class ChatViewModel {
    static let inputLimit = 2000

    private(set) var thread: ChatThread?
    var input: String
    var isConsentPresented = false
    private(set) var isWaiting = false
    /// The reply currently being revealed with the typing effect.
    private(set) var typingMessageID: UUID?

    /// Called once when the first question creates a new thread.
    var onThreadCreated: ((ChatThread) -> Void)?

    let client: (any LLMClienting)?
    var premiumAccess: PremiumAccess
    private let structured: Bool
    private let consent: AssistantConsent
    private let trialQuota: AssistantTrialQuota
    private var modelContext: ModelContext?
    private var activity: AppActivityContext?
    private var requestTask: Task<Void, Never>?
    private var pendingMessageID: UUID?
    private var pendingRequestID: UUID?
    private var pendingAccess: RequestAccess?

    private enum RequestAccess {
        case paid
        case trial(AssistantTrialQuota.Reservation)
    }

    init(
        thread: ChatThread?,
        client: (any LLMClienting)?,
        draft: String? = nil,
        structured: Bool = AppConfig.assistantStructuredReplies,
        access: PremiumAccess = PremiumAccess(),
        consent: AssistantConsent = AssistantConsent(),
        trialQuota: AssistantTrialQuota = .shared
    ) {
        self.thread = thread
        self.client = client
        self.input = String((draft ?? "").prefix(Self.inputLimit))
        self.structured = structured
        self.premiumAccess = access
        self.consent = consent
        self.trialQuota = trialQuota
    }

    /// Supplies the SwiftData context and the app activity used for the technical context.
    func attach(modelContext: ModelContext, activity: AppActivityContext?) {
        self.modelContext = modelContext
        self.activity = activity
        markUnansweredQuestionAsStopped()
    }

    /// A question left without a reply (e.g. the screen was closed while waiting) gets a Retry button.
    private func markUnansweredQuestionAsStopped() {
        guard !isWaiting, let last = messages.last, last.isUser, !last.isFailed else {
            return
        }
        markFailed(last, code: ChatMessage.stoppedErrorCode)
    }

    var messages: [ChatMessage] {
        thread?.sortedMessages ?? []
    }

    var isAvailable: Bool {
        client != nil
    }

    var canSend: Bool {
        isAvailable && !isBusy && !trimmedInput.isEmpty
    }

    /// Waiting for a reply or still typing it out.
    var isBusy: Bool {
        isWaiting || typingMessageID != nil
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Keeps the input within the technical 2000-character limit.
    func clampInput() {
        if input.count > Self.inputLimit {
            input = String(input.prefix(Self.inputLimit))
        }
    }

    /// Sends the text from the input field. A blocked send preserves the draft.
    func sendInput() {
        guard requireConsent(), canSend else { return }
        if sendQuestion(trimmedInput) {
            input = ""
        }
    }

    /// Sends a question, e.g. from a quick-question chip.
    func send(_ question: String) {
        guard requireConsent() else { return }
        _ = sendQuestion(question)
    }

    private func sendQuestion(_ question: String) -> Bool {
        let text = String(
            question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.inputLimit))
        guard isAvailable, !isBusy, !text.isEmpty, let modelContext,
            let access = acquireRequestAccess()
        else {
            return false
        }
        let thread = currentOrNewThread(firstQuestion: text, in: modelContext)
        let message = ChatMessage(role: ChatMessage.userRole, text: text)
        thread.messages.append(message)
        thread.updatedAt = .now
        save()
        request(for: message, access: access)
        return true
    }

    /// Re-sends a failed question through exactly the same quota and paid gate.
    func retry(_ message: ChatMessage) {
        guard requireConsent() else { return }
        guard isAvailable, modelContext != nil, message.isUser, message.isFailed, !isBusy,
            messages.contains(where: { $0.id == message.id }),
            let access = acquireRequestAccess()
        else {
            return
        }
        request(for: message, access: access)
    }

    private func acquireRequestAccess() -> RequestAccess? {
        if premiumAccess.assistantPaywallRoute == nil {
            return .paid
        }
        if let reservation = trialQuota.reserve() {
            return .trial(reservation)
        }
        // If the remaining slots are merely in flight in other models, wait for
        // their outcome without presenting a paywall before two successful replies.
        if trialQuota.isExhausted {
            _ = premiumAccess.authorize(.assistant)
        }
        return nil
    }

    /// Stops waiting for the current reply (the question stays with a Retry button)
    /// or shows the reply being typed in full.
    func stop() {
        finishTyping()
        guard isWaiting else {
            return
        }
        requestTask?.cancel()
        requestTask = nil
        if let id = pendingMessageID, let message = message(with: id) {
            markFailed(message, code: ChatMessage.stoppedErrorCode)
        }
        finishWaiting()
    }

    /// Ends the typing effect so the whole reply is shown.
    func finishTyping() {
        typingMessageID = nil
    }

    /// Cancels the request when the screen goes away.
    func cancelIfNeeded() {
        stop()
    }

    // MARK: - Consent

    /// Appearance only presents the disclosure; it never sends a message.
    func presentConsentIfNeeded() {
        _ = requireConsent()
    }

    /// Approval does not replay a blocked send or retry. The user chooses when to send.
    func approveConsent() {
        consent.approve()
        isConsentPresented = false
    }

    private func requireConsent() -> Bool {
        guard consent.isApproved else {
            isConsentPresented = true
            return false
        }
        return true
    }

    // MARK: - Request

    private func request(for message: ChatMessage, access: RequestAccess) {
        guard let client else { return }
        message.statusRaw = ChatMessage.sentStatus
        message.errorCode = nil
        isWaiting = true
        let messageID = message.id
        let requestID = UUID()
        pendingMessageID = messageID
        pendingRequestID = requestID
        pendingAccess = access

        let llmRequest = LLMRequest(messages: buildMessages(upTo: message), structured: structured)
        let structured = structured
        let isPaid: Bool
        switch access {
        case .paid: isPaid = true
        case .trial: isPaid = false
        }
        // Do not capture the reservation: its deinit releases the slot if this model
        // disappears, even when a client ignores cancellation and never returns.
        requestTask = Task { [weak self] in
            guard !Task.isCancelled, self?.pendingRequestID == requestID else { return }
            // Re-check at the asynchronous boundary before invoking the client.
            guard self?.requireConsent() == true else {
                self?.stop()
                return
            }
            if isPaid, self?.premiumAccess.authorize(.assistant) != true {
                self?.stop()
                return
            }
            do {
                let content = try await client.complete(llmRequest)
                // A cancelled client may still return. A retry of the same message
                // has a different request ID and must never accept that stale result.
                guard !Task.isCancelled, self?.pendingRequestID == requestID else { return }
                let reply = ReplyParser.parse(content, structured: structured)
                guard !reply.text.isEmpty else {
                    throw LLMError.emptyReply
                }
                self?.handle(reply: reply, for: messageID)
            } catch is CancellationError {
                self?.handleCancellation(for: requestID)
            } catch let error as LLMError {
                guard self?.pendingRequestID == requestID else { return }
                self?.handle(error: error, for: messageID)
            } catch {
                guard self?.pendingRequestID == requestID else { return }
                self?.handle(error: .server, for: messageID)
            }
        }
    }

    private func handleCancellation(for requestID: UUID) {
        guard pendingRequestID == requestID else { return }
        stop()
    }

    private func handle(reply: AssistantReply, for messageID: UUID) {
        guard pendingMessageID == messageID, let thread else {
            return
        }
        let answer = ChatMessage(
            role: ChatMessage.assistantRole,
            text: reply.text,
            actions: reply.actions.map(\.rawValue)
        )
        thread.messages.append(answer)
        thread.updatedAt = .now
        save()
        typingMessageID = answer.id
        if case .trial(let reservation) = pendingAccess {
            reservation.succeed()
        }
        finishWaiting()
    }

    private func handle(error: LLMError, for messageID: UUID) {
        guard pendingMessageID == messageID else {
            return
        }
        if let message = message(with: messageID) {
            markFailed(message, code: error.rawValue)
        }
        finishWaiting()
    }

    private func markFailed(_ message: ChatMessage, code: String) {
        message.statusRaw = ChatMessage.failedStatus
        message.errorCode = code
        save()
    }

    private func finishWaiting() {
        if case .trial(let reservation) = pendingAccess {
            reservation.cancel()
        }
        pendingAccess = nil
        pendingRequestID = nil
        isWaiting = false
        pendingMessageID = nil
        requestTask = nil
    }

    /// System prompt + history up to and including `message` (failed questions in between are skipped).
    private func buildMessages(upTo message: ChatMessage) -> [LLMMessage] {
        var history: [ChatTurn] = []
        for item in messages {
            if item.id == message.id {
                history.append(ChatTurn(role: .user, content: item.text))
                break
            }
            guard !item.isFailed else {
                continue
            }
            history.append(ChatTurn(role: item.isUser ? .user : .assistant, content: item.text))
        }
        let context =
            AssistantContextSetting.isEnabled() ? AssistantContext.current(activity: activity) : nil
        let languageName = PromptBuilder.languageName(forCode: PromptBuilder.interfaceLanguageCode)
        let system = PromptBuilder.systemPrompt(languageName: languageName, context: context)
        return PromptBuilder.messages(systemPrompt: system, history: history)
    }

    // MARK: - Storage

    private func currentOrNewThread(firstQuestion: String, in modelContext: ModelContext)
        -> ChatThread
    {
        if let thread {
            return thread
        }
        let thread = ChatThread(title: ChatThread.title(fromQuestion: firstQuestion))
        modelContext.insert(thread)
        self.thread = thread
        onThreadCreated?(thread)
        return thread
    }

    private func message(with id: UUID) -> ChatMessage? {
        thread?.messages.first { $0.id == id }
    }

    private func save() {
        try? modelContext?.save()
    }
}
