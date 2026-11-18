import SwiftUI

/// Three bouncing dots shown while the assistant prepares a reply. Static with Reduce Motion.
struct AssistantTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppColor.primary)
                        .frame(width: 8, height: 8)
                        .opacity(reduceMotion ? 0.55 : opacity(at: time, index: index))
                        .offset(y: reduceMotion ? 0 : offset(at: time, index: index))
                }
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m + 2)
        .background(AppColor.skyMist, in: AssistantBubbleShape(isUser: false))
        .accessibilityElement()
        .accessibilityLabel(Text("Assistant is typing"))
    }

    private func phase(at time: TimeInterval, index: Int) -> Double {
        let cycle = 1.2
        let shifted = time / cycle - Double(index) * 0.18
        let value = shifted - floor(shifted)
        return max(0, sin(value * 2 * .pi))
    }

    private func opacity(at time: TimeInterval, index: Int) -> Double {
        0.35 + 0.65 * phase(at: time, index: index)
    }

    private func offset(at time: TimeInterval, index: Int) -> CGFloat {
        -4 * phase(at: time, index: index)
    }
}

/// Chat bubble with a smaller corner on the speaker's side.
struct AssistantBubbleShape: Shape {
    var isUser: Bool

    func path(in rect: CGRect) -> Path {
        let large: CGFloat = 20
        let small: CGFloat = 6
        let radii = RectangleCornerRadii(
            topLeading: large,
            bottomLeading: isUser ? large : small,
            bottomTrailing: isUser ? small : large,
            topTrailing: large
        )
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
    }
}

#Preview {
    AssistantTypingIndicator()
        .padding()
}
