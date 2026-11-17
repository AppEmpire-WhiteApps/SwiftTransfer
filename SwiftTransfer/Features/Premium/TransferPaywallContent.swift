import PremiumKit
import SwiftUI

struct TransferPaywallContent: View {
    let route: PremiumRoute
    let onDismiss: () -> Void
    @State private var loaded = false
    @State private var catalogReady = false

    var body: some View {
        GeometryReader { proxy in
            let layout = PremiumLayout(size: proxy.size)
            ZStack(alignment: .topTrailing) {
                AppGradient.hero.ignoresSafeArea()
                if PremiumSetup.isConfigured && !loaded {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if hasCatalog {
                    builder(scale: layout.scale)
                } else {
                    PremiumUnavailableView(
                        route: route, onRestored: onDismiss, onRetry: loadCatalog)
                }
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.85), in: Circle())
                }
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("premium.close")
                .padding(.trailing, 12)
            }
        }
        .task { await loadCatalog() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall.\(route.rawValue)")
    }

    private var hasCatalog: Bool {
        PremiumSetup.isConfigured && loaded && catalogReady
    }

    @MainActor
    private func loadCatalog() async {
        guard PremiumSetup.isConfigured else { return }
        loaded = false
        catalogReady = await PremiumCatalog.load(route.paywallID)
        loaded = true
    }

    @ViewBuilder
    private func builder(scale: CGFloat) -> some View {
        switch route {
        case .main:
            PaywallBuilder(
                images: PremiumDesign.resources,
                style: PremiumDesign.main(scale: scale),
                linksConfig: PremiumDesign.links,
                showCloseButton: false,
                navigationBarHidden: true,
                termsView: { PremiumLegalScreen(document: .terms) },
                privacyView: { PremiumLegalScreen(document: .privacy) },
                backgroundView: AnyView(AppGradient.hero),
                middleView: AnyView(PremiumArtwork(route: .main)),
                onDismiss: onDismiss,
                onSuccess: onDismiss
            )
        case .assistant:
            SecondaryPaywallBuilder(
                paywallID: route.paywallID,
                images: AdaptiveResources(iphone: Image("paywall_assistant")),
                style: PremiumDesign.assistant(scale: scale),
                linksConfig: PremiumDesign.links,
                showCloseButton: false,
                navigationBarHidden: true,
                termsView: { PremiumLegalScreen(document: .terms) },
                privacyView: { PremiumLegalScreen(document: .privacy) },
                backgroundView: AnyView(AppGradient.hero),
                middleView: AnyView(PremiumArtwork(route: .assistant)),
                onDismiss: onDismiss,
                onSuccess: onDismiss
            )
        }
    }
}

private struct PremiumUnavailableView: View {
    let route: PremiumRoute
    let onRestored: () -> Void
    let onRetry: () async -> Void
    @State private var document: PremiumLegalDocument?
    @State private var restoring = false
    @State private var restoreMessage = false
    @State private var restoreError = ""

    var body: some View {
        VStack(spacing: 16) {
            PremiumArtwork(route: route)
            VStack(spacing: 12) {
                Text(
                    route == .main ? "Unlock your next move" : "Your AI transfer assistant",
                    tableName: "Premium"
                )
                .font(AppFont.title1)
                .foregroundStyle(AppColor.textPrimary)
                Text(
                    "Subscriptions are currently unavailable. Please try again later.",
                    tableName: "Premium"
                )
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
                Button {
                    Task { await onRetry() }
                } label: {
                    Text("Subscriptions unavailable", tableName: "Premium")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            AppColor.primary,
                            in: RoundedRectangle(cornerRadius: PremiumDesign.cornerRadius))
                }
                .disabled(!PremiumSetup.isConfigured)
                .accessibilityIdentifier("premium.unavailable")
                HStack(spacing: 16) {
                    Button(PremiumDesign.links.termsTitle) { document = .terms }
                    Button(PremiumDesign.links.restoreTitle) {
                        guard !restoring else { return }
                        Task {
                            restoring = true
                            defer { restoring = false }
                            guard PremiumSetup.isConfigured else {
                                restoreError = String(
                                    localized:
                                        "Subscriptions are currently unavailable. Please try again later.",
                                    table: "Premium")
                                restoreMessage = true
                                return
                            }
                            switch await Premium.shared.restore() {
                            case .success:
                                onRestored()
                            case .failure(let error):
                                restoreError = error.localizedDescription
                                restoreMessage = true
                            }
                        }
                    }
                    .disabled(restoring)
                    Button(PremiumDesign.links.privacyTitle) { document = .privacy }
                }
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, 8)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
        }
        .padding(.top, 44)
        .sheet(item: $document) { document in
            PremiumLegalScreen(document: document)
        }
        .alert(Text("Restore", tableName: "Premium"), isPresented: $restoreMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreError)
        }
    }
}
