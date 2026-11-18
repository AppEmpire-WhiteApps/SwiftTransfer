import PremiumKit
import SwiftUI

struct TransferPaywallContent: View {
    let route: PremiumRoute
    let onDismiss: () -> Void

    var body: some View {
        Group {
            switch route {
            case .main:
                mainPaywall
            case .assistant:
                TransferAssistantPaywall(onComplete: onDismiss)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall.\(route.rawValue)")
    }

    private var mainPaywall: some View {
        GeometryReader { proxy in
            PaywallBuilder(
                images: PremiumDesign.resources,
                style: PremiumDesign.main(scale: PremiumLayout(size: proxy.size).scale),
                linksConfig: PremiumDesign.links,
                termsView: { PremiumLegalScreen(document: .terms) },
                privacyView: { PremiumLegalScreen(document: .privacy) },
                backgroundView: AnyView(
                    PremiumScreenBackground(kind: .main) {
                        PremiumArtwork(route: .main)
                    }
                ),
                secondaryPaywallView: AnyView(
                    TransferAssistantPaywall(onComplete: onDismiss)
                ),
                onDismiss: onDismiss,
                onSuccess: onDismiss
            )
        }
    }
}

struct TransferAssistantPaywall: View {
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { proxy in
            SecondaryPaywallBuilder(
                paywallID: PremiumRoute.assistant.paywallID,
                images: PremiumDesign.assistantResources,
                style: PremiumDesign.assistant(scale: PremiumLayout(size: proxy.size).scale),
                linksConfig: PremiumDesign.links,
                showCloseButton: false,
                termsView: { PremiumLegalScreen(document: .terms) },
                privacyView: { PremiumLegalScreen(document: .privacy) },
                backgroundView: AnyView(
                    PremiumScreenBackground(kind: .assistant) {
                        PremiumArtwork(route: .assistant)
                    }
                ),
                onDismiss: onComplete,
                onSuccess: onComplete
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall.assistant")
    }
}
