import SwiftUI
import UIKit

/// One chat message: user bubble on the trailing side, assistant bubble with avatar and action chips
/// on the leading side. Failed questions show the error and a Retry button.
struct AssistantMessageRow: View {
    let message: ChatMessage
    /// Reveal the reply with the typing effect (only for a reply that has just arrived).
    var isTyping = false
    var onRetry: () -> Void = {}
    var onAction: (AssistantAction) -> Void = { _ in }
    var onTypingProgress: () -> Void = {}
    var onTypingFinished: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var maxBubbleWidth: CGFloat {
        sizeClass == .regular ? 560 : 520
    }

    var body: some View {
        if message.isUser {
            userRow
        } else {
            assistantRow
        }
    }

    private var userRow: some View {
        VStack(alignment: .trailing, spacing: Spacing.s) {
            HStack {
                Spacer(minLength: Spacing.xxxl + Spacing.l)
                Text(message.text)
                    .font(AppFont.body)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .background(AppGradient.primary, in: AssistantBubbleShape(isUser: true))
                    .shadow(color: AppColor.primary.opacity(0.18), radius: 8, x: 0, y: 4)
                    .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
                    .contextMenu { messageMenu }
                    .accessibilityLabel(Text("You: \(message.text)"))
            }
            if message.isFailed {
                failureFooter
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .bottom, spacing: Spacing.s) {
                AssistantAvatar()
                replyText
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .background(AppColor.skyMist, in: AssistantBubbleShape(isUser: false))
                    .contextMenu { messageMenu }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Assistant: \(message.text)"))
                    .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                Spacer(minLength: Spacing.xl)
            }
            if !message.actions.isEmpty && !isTyping {
                AssistantFlowLayout {
                    ForEach(message.actions, id: \.self) { action in
                        Button {
                            onAction(action)
                        } label: {
                            Chip(title: Text(action.title), systemImage: action.systemImage)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Opens this section of the app"))
                    }
                }
                .frame(maxWidth: maxBubbleWidth, alignment: .leading)
                .padding(.leading, AssistantAvatar.defaultSize + Spacing.s)
                .padding(.trailing, Spacing.xl)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.25), value: isTyping)
    }

    @ViewBuilder
    private var replyText: some View {
        if isTyping {
            AssistantTypewriterText(text: message.text, onProgress: onTypingProgress, onFinish: onTypingFinished)
        } else {
            AssistantMarkdownText(message.text)
        }
    }

    private var failureFooter: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: message.failure == nil ? "stop.circle" : "exclamationmark.circle.fill")
                .foregroundStyle(message.failure == nil ? AppColor.textTertiary : AppColor.error)
                .accessibilityHidden(true)
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                failureText
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(AppFont.callout.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColor.primary)
                .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
        .accessibilityElement(children: .combine)
    }

    private var failureText: Text {
        if let failure = message.failure {
            Text(failure.message)
        } else {
            Text("Stopped. Tap Retry to ask again.")
        }
    }

    @ViewBuilder
    private var messageMenu: some View {
        Button {
            UIPasteboard.general.string = message.text
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        ShareLink(item: message.text) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}

/// Small round assistant avatar next to replies.
struct AssistantAvatar: View {
    static let defaultSize: CGFloat = 32

    var size: CGFloat = AssistantAvatar.defaultSize

    var body: some View {
        Illustration.assistantAvatar.image
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .background(AppColor.surface)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(AppColor.skyLight, lineWidth: 1))
            .shadow(color: AppColor.primary.opacity(0.12), radius: 4, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}

#Preview {
    let question = ChatMessage(role: ChatMessage.userRole, text: "How do I move photos to Android?")
    let reply = ChatMessage(
        role: ChatMessage.assistantRole,
        text: "1. Connect to the **same Wi-Fi**.\n2. Tap **Send data**.\n3. Scan the QR code.",
        actions: [AssistantAction.startSend.rawValue, AssistantAction.openGuideWifiGalaxy.rawValue]
    )
    let failed = ChatMessage(role: ChatMessage.userRole, text: "And videos?", status: ChatMessage.failedStatus)
    failed.errorCode = LLMError.busy.rawValue
    return ScrollView {
        VStack(spacing: Spacing.l) {
            AssistantMessageRow(message: question)
            AssistantMessageRow(message: reply)
            AssistantMessageRow(message: failed)
        }
        .padding()
    }
    .screenBackground()
}
