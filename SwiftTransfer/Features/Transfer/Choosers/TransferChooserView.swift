import SwiftUI

/// S3: "Where to?" (send) or "From where?" (receive) with big illustrated cards.
struct TransferChooserView: View {
    enum Kind {
        case target
        case origin
    }

    enum Choice: Hashable {
        case target(TransferTarget)
        case origin(TransferOrigin)
    }

    private struct Option: Identifiable {
        let choice: Choice
        let illustration: Illustration
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let badge: LocalizedStringKey?

        var id: Choice { choice }
    }

    let kind: Kind
    let onChoose: (Choice) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var options: [Option] {
        switch kind {
        case .target:
            [
                Option(
                    choice: .target(.android),
                    illustration: .deviceAndroid,
                    title: "Android phone",
                    subtitle: "Over Wi-Fi in the phone's browser. Nothing to install on Android (e.g. Samsung Galaxy).",
                    badge: "No app needed"
                ),
                Option(
                    choice: .target(.storage),
                    illustration: .deviceStorage,
                    title: "Cable or drive",
                    subtitle: "Move data to Android using a USB drive, SD card or computer.",
                    badge: nil
                ),
            ]
        case .origin:
            [
                Option(
                    choice: .origin(.android),
                    illustration: .deviceAndroid,
                    title: "From Android",
                    subtitle: "The Android phone opens a page in its browser and uploads photos, videos, contacts and files.",
                    badge: "No app needed"
                ),
            ]
        }
    }

    private var columns: [GridItem] {
        sizeClass == .regular
            ? [GridItem(.adaptive(minimum: 300), spacing: Spacing.l, alignment: .top)]
            : [GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(kind == .target ? "Where to?" : "From where?")
                        .font(AppFont.display)
                        .foregroundStyle(AppColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(kind == .target
                        ? "Choose the device that receives your data. Everything stays on this iPhone — it's a copy."
                        : "Choose the device that has your data.")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: columns, spacing: Spacing.l) {
                    ForEach(options) { option in
                        Button {
                            onChoose(option.choice)
                        } label: {
                            ChooserCard(option: option)
                        }
                        .buttonStyle(ChooserCardButtonStyle())
                    }
                }
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .trackScreen(kind == .target ? "transfer_choose_target" : "transfer_choose_origin")
    }

    private struct ChooserCard: View {
        let option: Option

        var body: some View {
            HStack(spacing: Spacing.l) {
                option.illustration.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .background(AppGradient.glow(radius: 60))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(option.title)
                        .font(AppFont.title2)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(option.subtitle)
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let badge = option.badge {
                        Text(badge)
                            .font(AppFont.caption.weight(.semibold))
                            .foregroundStyle(AppColor.primary)
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, Spacing.xs)
                            .background(AppColor.skyMist, in: Capsule())
                            .padding(.top, Spacing.xs)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .accessibilityElement(children: .combine)
        }
    }
}

private struct ChooserCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview("Where to") {
    NavigationStack {
        TransferChooserView(kind: .target) { _ in }
            .screenBackground()
    }
    .environment(AppActivityContext())
}

#Preview("From where") {
    NavigationStack {
        TransferChooserView(kind: .origin) { _ in }
            .screenBackground()
    }
    .environment(AppActivityContext())
}
