import SwiftUI

/// Gradient filled main action button (height 56, radius 16).
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.s) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
            configuration.label
        }
        .font(AppFont.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, Spacing.l)
        .background {
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .fill(isEnabled ? AnyShapeStyle(AppGradient.primary) : AnyShapeStyle(AppColor.textTertiary.opacity(0.5)))
        }
        .shadow(color: AppColor.primary.opacity(isEnabled ? 0.25 : 0), radius: 12, x: 0, y: 6)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .opacity(configuration.isPressed ? 0.9 : 1)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// White button with a primary outline.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .foregroundStyle(isEnabled ? AppColor.primary : AppColor.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, Spacing.l)
            .background(
                AppColor.surface,
                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(isEnabled ? AppColor.primary : AppColor.divider, lineWidth: 1.5)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Plain text button in the primary color.
struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .foregroundStyle(AppColor.primary)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }

    static func primary(isLoading: Bool) -> PrimaryButtonStyle {
        PrimaryButtonStyle(isLoading: isLoading)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
}

#Preview {
    VStack(spacing: Spacing.l) {
        Button("Send data") {}
            .buttonStyle(.primary)
        Button("Connecting") {}
            .buttonStyle(.primary(isLoading: true))
        Button("Disabled") {}
            .buttonStyle(.primary)
            .disabled(true)
        Button("Receive data") {}
            .buttonStyle(.secondary)
        Button("How does it work?") {}
            .buttonStyle(.text)
    }
    .padding()
    .screenBackground()
}
