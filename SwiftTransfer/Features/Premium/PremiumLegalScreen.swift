import SwiftUI

/// Shared sheet identity for the paywalls' custom legal destinations.
enum PremiumLegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    fileprivate var titleKey: String {
        "legal_\(rawValue)_title"
    }

    fileprivate var sectionKeys: [String] {
        switch self {
        case .terms:
            [
                "legal_terms_use",
                "legal_terms_purchase",
                "legal_terms_renewal",
                "legal_terms_restore",
                "legal_terms_ai",
                "legal_terms_rights",
            ]
        case .privacy:
            [
                "legal_privacy_transfer",
                "legal_privacy_permissions",
                "legal_privacy_ai",
                "legal_privacy_purchase",
                "legal_privacy_history",
                "legal_privacy_providers",
            ]
        }
    }
}

/// Self-contained destination for a sheet or a PremiumKit custom legal view.
/// All copy is intentionally kept in the dedicated PremiumLegal string table.
struct PremiumLegalScreen: View {
    let document: PremiumLegalDocument

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    draftNotice

                    ForEach(document.sectionKeys, id: \.self) { key in
                        legalSection(key)
                    }
                }
                .padding(Spacing.xl)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle(localizedText(document.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColor.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        localizedText("legal_close")
                            .font(AppFont.headline)
                    }
                    .accessibilityIdentifier("premium.legal.close")
                }
            }
        }
        .tint(AppColor.primary)
        .preferredColorScheme(.light)
        .accessibilityIdentifier("premium.legal.\(document.rawValue)")
    }

    private var draftNotice: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top, spacing: Spacing.s) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(AppColor.primary)
                    .accessibilityHidden(true)

                localizedText("legal_draft_title")
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }

            localizedText("legal_draft_body")
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
                .textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.skyLight,
            in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
        )
    }

    private func legalSection(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            localizedText("\(key)_title")
                .font(AppFont.title2)
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            localizedText("\(key)_body")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func localizedText(_ key: String) -> Text {
        Text(LocalizedStringKey(key), tableName: "PremiumLegal")
    }
}
