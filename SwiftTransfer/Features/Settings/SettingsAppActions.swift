import SwiftUI
import UIKit

struct SettingsAppActions: View {
    @Environment(\.openURL) private var openURL
    @State private var legalDocument: PremiumLegalDocument?
    @State private var showsSupportEmail = false
    @State private var showsStoreError = false

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            sharingSection
            supportSection
            legalSection
        }
        .sheet(item: $legalDocument) { document in
            PremiumLegalScreen(document: document)
        }
        .alert("Contact support", isPresented: $showsSupportEmail) {
            Button("Copy email") {
                UIPasteboard.general.string = AppConfig.supportEmail
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: AppConfig.supportEmail)
        }
        .alert("Couldn't open the App Store", isPresented: $showsStoreError) {
            Button("OK", role: .cancel) {}
        }
    }

    private var sharingSection: some View {
        SettingsSection(title: "About the app") {
            if let url = AppConfig.appStoreURL {
                ShareLink(item: url) {
                    SettingsRowLabel(title: "Share app", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.shareApp")
                SettingsDivider()
            }
            Button {
                openStoreReview()
            } label: {
                SettingsRowLabel(title: "Rate the app", systemImage: "star.fill") {
                    SettingsChevron(systemImage: "arrow.up.right")
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.rateApp")
        }
    }

    private var supportSection: some View {
        SettingsSection(title: "Support") {
            Button {
                contactSupport()
            } label: {
                SettingsRowLabel(
                    title: "Contact support", systemImage: "envelope.fill",
                    subtitle: Text(verbatim: AppConfig.supportEmail)
                ) {
                    SettingsChevron(systemImage: "arrow.up.right")
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.support")
        }
    }

    private var legalSection: some View {
        SettingsSection(title: "Legal") {
            Button {
                legalDocument = .privacy
            } label: {
                SettingsRowLabel(title: "Privacy Policy", systemImage: "hand.raised.fill")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.privacy")
            SettingsDivider()
            Button {
                legalDocument = .terms
            } label: {
                SettingsRowLabel(title: "Terms of Use", systemImage: "doc.text.fill")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.terms")
        }
    }

    private func openStoreReview() {
        guard let url = AppConfig.reviewURL else {
            showsStoreError = true
            return
        }
        openURL(url) { accepted in
            if !accepted {
                showsStoreError = true
            }
        }
    }

    private func contactSupport() {
        guard let url = SettingsSupportMail.url() else {
            showsSupportEmail = true
            return
        }
        openURL(url) { accepted in
            if !accepted {
                showsSupportEmail = true
            }
        }
    }
}
