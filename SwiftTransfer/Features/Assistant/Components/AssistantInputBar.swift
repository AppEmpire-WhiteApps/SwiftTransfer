import SwiftUI

/// Multi-line message field (up to 6 lines) with Send, or Stop while a reply is pending.
struct AssistantInputBar: View {
    @Binding var text: String
    let isWaiting: Bool
    let canSend: Bool
    var onSend: () -> Void
    var onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.s) {
            TextField("Ask about your transfer", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .font(AppFont.body)
                .foregroundStyle(AppColor.textPrimary)
                .focused($isFocused)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m - 1)
                .frame(minHeight: 44)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isFocused ? AppColor.sky : AppColor.divider, lineWidth: 1)
                }
                .accessibilityLabel(Text("Message"))

            if isWaiting {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.body.weight(.bold))
                        .foregroundStyle(AppColor.primary)
                        .frame(width: 44, height: 44)
                        .background(AppColor.skyLight, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Stop"))
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(sendBackground, in: Circle())
                        .shadow(color: AppColor.primary.opacity(canSend ? 0.25 : 0), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel(Text("Send"))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: isWaiting)
        .padding(.vertical, Spacing.s)
    }

    private var sendBackground: AnyShapeStyle {
        canSend ? AnyShapeStyle(AppGradient.primary) : AnyShapeStyle(AppColor.textTertiary.opacity(0.45))
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack {
        AssistantInputBar(text: $text, isWaiting: false, canSend: !text.isEmpty, onSend: {}, onStop: {})
        AssistantInputBar(text: .constant("Why is it slow?"), isWaiting: true, canSend: false, onSend: {}, onStop: {})
    }
    .padding()
    .screenBackground()
}
