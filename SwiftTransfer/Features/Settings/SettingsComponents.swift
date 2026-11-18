import SafariServices
import SwiftUI
import UIKit

/// A titled group of settings rows rendered as a card.
struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    var footer: LocalizedStringKey?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(AppFont.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .textCase(.uppercase)
                .padding(.leading, Spacing.xs)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: Radius.card - 4, style: .continuous))
            .shadow(color: AppColor.primary.opacity(0.07), radius: 12, x: 0, y: 6)
            if let footer {
                Text(footer)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.xs)
            }
        }
    }
}

/// Icon tile + title (+ subtitle) + trailing content.
struct SettingsRowLabel<Trailing: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var subtitle: Text?
    var tint: Color = AppColor.primary
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(AppColor.skyMist, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(tint == AppColor.error ? AppColor.error : AppColor.textPrimary)
                if let subtitle {
                    subtitle
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: Spacing.s)
            trailing
        }
        .padding(.vertical, Spacing.m)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

extension SettingsRowLabel where Trailing == SettingsChevron {
    init(
        title: LocalizedStringKey,
        systemImage: String,
        subtitle: Text? = nil,
        tint: Color = AppColor.primary
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.tint = tint
        self.trailing = SettingsChevron()
    }
}

/// Trailing chevron of a navigable row.
struct SettingsChevron: View {
    var systemImage = "chevron.right"

    var body: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppColor.textTertiary)
            .accessibilityHidden(true)
    }
}

/// Thin divider between rows, aligned with the row titles.
struct SettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(AppColor.divider)
            .padding(.leading, 46)
    }
}

/// A URL shown in an in-app Safari sheet.
struct SettingsSafariLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// `SFSafariViewController` for the privacy policy and terms.
struct SettingsSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(AppColor.primary)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    ScrollView {
        SettingsSection(title: "Transfer", footer: "Applies to new transfers.") {
            SettingsRowLabel(title: "App language", systemImage: "globe", subtitle: Text("Opens iOS Settings"))
            SettingsDivider()
            SettingsRowLabel(title: "Keep screen awake", systemImage: "sun.max") {
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
            }
        }
        .padding()
    }
    .screenBackground()
}
