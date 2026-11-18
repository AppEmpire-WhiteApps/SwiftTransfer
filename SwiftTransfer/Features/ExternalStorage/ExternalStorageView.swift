import SwiftUI

/// Screen S8 "Cable & drive" (TZ §4.8): save to an external drive, restore from a drive,
/// or prepare for a direct cable transfer to Android.
struct ExternalStorageView: View {
    enum Option: String, Identifiable, Hashable, CaseIterable {
        case saveToDrive
        case restoreFromDrive
        case cable

        var id: String { rawValue }
    }

    @State private var destination: Option?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        sizeClass == .regular
            ? [GridItem(.flexible(), spacing: Spacing.l, alignment: .top), GridItem(.flexible(), spacing: Spacing.l, alignment: .top)]
            : [GridItem(.flexible(), alignment: .top)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("No Wi-Fi? Use a drive or a cable")
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Copy your data to a USB-C flash drive or SSD, restore it from a drive, or connect the phones with a cable.")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: columns, spacing: Spacing.l) {
                    optionCard(
                        .saveToDrive,
                        illustration: .storageDrive,
                        title: "Save to an external drive",
                        message: "Contacts, calendar, photos and files in folders any Android phone or computer can open.",
                        systemImage: "externaldrive.badge.plus"
                    )
                    optionCard(
                        .restoreFromDrive,
                        illustration: .deviceStorage,
                        title: "Restore from a drive",
                        message: "Import a transfer package or Android photos and files from a drive into this iPhone.",
                        systemImage: "square.and.arrow.down"
                    )
                    optionCard(
                        .cable,
                        illustration: .methodCable,
                        title: "Direct cable to Android",
                        message: "Get this iPhone ready, then use the Android phone's own transfer app (e.g. Smart Switch on Samsung Galaxy).",
                        systemImage: "cable.connector"
                    )
                }
            }
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
            .pageMargins()
        }
        .screenBackground()
        .navigationTitle(Text("Cable & drive"))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("external_storage")
        .navigationDestination(item: $destination) { option in
            switch option {
            case .saveToDrive:
                DriveExportView()
            case .restoreFromDrive:
                DriveRestoreView()
            case .cable:
                CablePrepView()
            }
        }
    }

    private func optionCard(
        _ option: Option,
        illustration: Illustration,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        Button {
            destination = option
        } label: {
            VStack(alignment: .leading, spacing: Spacing.m) {
                IllustrationView(illustration: illustration, height: sizeClass == .regular ? 170 : 140)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Image(systemName: systemImage)
                        .foregroundStyle(AppColor.primary)
                    Text(title)
                        .font(AppFont.title2)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
                Text(message)
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    NavigationStack {
        ExternalStorageView()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}
