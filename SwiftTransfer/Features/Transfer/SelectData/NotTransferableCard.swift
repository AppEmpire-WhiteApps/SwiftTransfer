import SwiftUI

/// Expandable "What can't be transferred" block with a shortcut to the assistant (TZ §1.4, §4.3.1).
struct NotTransferableCard: View {
    @Environment(AppRouter.self) private var router
    @State private var isExpanded = false

    private let items: [(LocalizedStringKey, String)] = [
        ("SMS and iMessage", "message"),
        ("Call history", "phone"),
        ("Apple Notes", "note.text"),
        ("Voice memos", "waveform"),
        ("Passwords and keychain", "key"),
        ("Wi-Fi networks", "wifi"),
        ("Apps and their data", "square.grid.2x2"),
        ("Music with DRM (Apple Music)", "music.note"),
        ("System settings", "gearshape"),
        ("Wallpapers", "photo.artframe"),
        ("Alarms", "alarm"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(AppColor.primary)
                    Text("What can't be transferred")
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))

            if isExpanded {
                Text("iOS doesn't let apps read this data, so no transfer app can copy it.")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ForEach(items.indices, id: \.self) { index in
                        Label {
                            Text(items[index].0)
                                .foregroundStyle(AppColor.textPrimary)
                        } icon: {
                            Image(systemName: items[index].1)
                                .foregroundStyle(AppColor.sky)
                        }
                        .font(AppFont.callout)
                    }
                }
                Text("Contacts are transferred; the notes field inside contact cards is not included.")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    router.askAssistant(draft: String(localized: "How can I move my messages, notes, passwords and other data that the app can't transfer?"))
                } label: {
                    Label("Ask the assistant how to move this", systemImage: "sparkles")
                }
                .buttonStyle(.secondary)
            }
        }
        .cardStyle()
    }
}

#Preview {
    NotTransferableCard()
        .padding()
        .screenBackground()
        .environment(AppRouter())
}
