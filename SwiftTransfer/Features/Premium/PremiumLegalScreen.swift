import SwiftUI

/// Shared sheet identity for Settings and the PremiumKit custom legal destinations.
enum PremiumLegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    fileprivate var titleKey: String {
        "legal_\(rawValue)_title"
    }

    // The operator supplied these legal documents in English; all entry points use the same copy.
    func loadContent(bundle: Bundle = .main) throws -> PremiumLegalContent {
        let resource = "swifttransfer-\(rawValue)-en"
        guard
            let url = bundle.url(
                forResource: resource, withExtension: "json", subdirectory: "Legal")
                ?? bundle.url(forResource: resource, withExtension: "json")
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(PremiumLegalContent.self, from: Data(contentsOf: url))
    }
}

struct PremiumLegalContent: Decodable {
    struct Section: Decodable {
        let title: String
        let paragraphs: [String]
    }

    let title: String
    let effectiveDate: String
    let sections: [Section]
}

struct PremiumLegalScreen: View {
    let document: PremiumLegalDocument

    @Environment(\.dismiss) private var dismiss
    @State private var content: PremiumLegalContent?
    @State private var loadingFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xxl) {
                    if let content {
                        legalContent(content)
                    } else if loadingFailed {
                        Text("Couldn't open the file")
                            .font(AppFont.headline)
                        if let url = URL(string: "mailto:\(AppConfig.supportEmail)") {
                            Link(AppConfig.supportEmail, destination: url)
                        }
                    } else {
                        ProgressView()
                            .tint(AppColor.primary)
                            .frame(maxWidth: .infinity)
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
            .task(id: document) {
                content = nil
                loadingFailed = false
                do {
                    content = try document.loadContent()
                } catch {
                    loadingFailed = true
                }
            }
        }
        .tint(AppColor.primary)
        .preferredColorScheme(.light)
        .accessibilityIdentifier("premium.legal.\(document.rawValue)")
    }

    private func legalContent(_ content: PremiumLegalContent) -> some View {
        Group {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(verbatim: content.title)
                    .font(AppFont.title2)
                    .foregroundStyle(AppColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: "Effective date: \(content.effectiveDate)")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
            ForEach(Array(content.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text(verbatim: section.title)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(verbatim: paragraph)
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .textSelection(.enabled)
    }

    private func localizedText(_ key: String) -> Text {
        Text(LocalizedStringKey(key), tableName: "PremiumLegal")
    }
}
