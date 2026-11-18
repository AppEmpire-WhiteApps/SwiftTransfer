import SwiftUI

/// Permission primer (TZ §4.3.3): illustration, two lines of explanation and "Allow access".
/// When access was denied it explains how to enable it and offers "Open Settings".
struct PermissionPrimerView: View {
    let kind: PermissionKind
    let state: PermissionState
    var onAllow: () -> Void
    var onClose: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(illustration: .permissionAccess, height: sizeClass == .regular ? 220 : 180, floating: true)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.s) {
                    Text(titleText)
                        .font(AppFont.title2)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(kind.primerMessage)
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)

                if state.isBlocked {
                    Label {
                        Text("Access is turned off. Open Settings and allow access for this app.")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.skyMist, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                }

                VStack(spacing: Spacing.s) {
                    if state.isBlocked {
                        Button {
                            PermissionsService.openSettings()
                        } label: {
                            Label("Open Settings", systemImage: "gear")
                        }
                        .buttonStyle(.primary)
                    } else {
                        Button("Allow access", action: onAllow)
                            .buttonStyle(.primary)
                    }
                    Button("Not now", action: onClose)
                        .buttonStyle(.text)
                }
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
            .pageMargins()
        }
        .screenBackground()
        .trackScreen("permission_primer")
    }

    private var titleText: LocalizedStringResource {
        switch kind {
        case .contacts: "Access to Contacts"
        case .calendar: "Access to Calendar"
        case .reminders: "Access to Reminders"
        case .photos: "Access to Photos"
        case .photosAddOnly: "Save to Photos"
        case .camera: "Access to the camera"
        }
    }
}

#Preview("Primer") {
    PermissionPrimerView(kind: .photos, state: .notDetermined, onAllow: {}, onClose: {})
        .environment(AppActivityContext())
}

#Preview("Denied") {
    PermissionPrimerView(kind: .contacts, state: .denied, onAllow: {}, onClose: {})
        .environment(AppActivityContext())
}
