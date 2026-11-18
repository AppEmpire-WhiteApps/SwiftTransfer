import PremiumKit
import SwiftUI

struct TransferOnboardingExperience: View {
    let onFinish: () -> Void
    @State private var page = 0
    var body: some View {
        GeometryReader { proxy in
            OnboardingBuilder(
                screens: screens(safeAreaTop: proxy.safeAreaInsets.top),
                paywallImages: PremiumDesign.resources,
                style: PremiumDesign.onboarding(scale: PremiumLayout(size: proxy.size).scale),
                linksConfig: PremiumDesign.links,
                isTrialEnabled: false,
                showReviewRequestOnComplete: true,
                termsView: { PremiumLegalScreen(document: .terms) },
                privacyView: { PremiumLegalScreen(document: .privacy) },
                paywallBackgroundView: AnyView(
                    PremiumScreenBackground(kind: .onboarding) {
                        PremiumArtwork(route: .main)
                    }
                ),
                secondaryPaywallID: PremiumRoute.assistant.paywallID,
                secondaryPaywallImages: PremiumDesign.assistantResources,
                secondaryPaywallBackgroundView: AnyView(
                    PremiumScreenBackground(kind: .onboarding) {
                        PremiumArtwork(route: .assistant)
                    }
                ),
                onComplete: onFinish
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.\(page)")
    }

    private func screens(safeAreaTop: CGFloat) -> [OnboardingScreen] {
        [
            OnboardingScreen(
                id: 0,
                title1: String(localized: "Move to a new phone", table: "Premium"),
                title2: String(localized: "In just a few steps", table: "Premium"),
                subtitle: String(
                    localized: "Between iPhone and Android\nOver Wi-Fi or with an external drive",
                    table: "Premium"),
                message: String(localized: "Your old phone keeps its data", table: "Premium"),
                buttonTitle: String(localized: "Continue"),
                images: AdaptiveResources(iphone: Image("onb_transfer")),
                backgroundView: AnyView(
                    PremiumScreenBackground(kind: .onboarding, safeAreaTop: safeAreaTop) {
                        OnboardingFeatureScene(story: .transfer)
                    }
                )
            ),
            OnboardingScreen(
                id: 1,
                title1: String(localized: "Your photos and contacts", table: "Premium"),
                title2: String(localized: "Your choice of what moves", table: "Premium"),
                subtitle: String(
                    localized: "Choose photos, videos and more\nBring files from the Files app too",
                    table: "Premium"),
                message: String(localized: "Select only what matters to you", table: "Premium"),
                buttonTitle: String(localized: "Continue"),
                images: AdaptiveResources(iphone: Image("onb_data_types")),
                backgroundView: AnyView(
                    PremiumScreenBackground(kind: .onboarding, safeAreaTop: safeAreaTop) {
                        OnboardingFeatureScene(story: .selection)
                    }
                )
            ),
            OnboardingScreen(
                id: 2,
                title1: String(localized: "We value", table: "Premium"),
                title2: String(localized: "Your feedback", table: "Premium"),
                subtitle: String(
                    localized:
                        "Tell us about your transfer\nYour feedback helps us improve",
                    table: "Premium"),
                message: String(localized: "Every transfer story matters", table: "Premium"),
                buttonTitle: String(localized: "Continue"),
                images: PremiumDesign.resources,
                backgroundView: AnyView(
                    PremiumScreenBackground(kind: .onboarding, safeAreaTop: safeAreaTop) {
                        OnboardingReviews()
                    }
                )
            ),
            OnboardingScreen(
                id: 3,
                title1: String(localized: "A guide for every step", table: "Premium"),
                title2: String(localized: "Help when you need it", table: "Premium"),
                subtitle: String(
                    localized: "Follow a clear transfer guide\nAsk the AI assistant for help",
                    table: "Premium"),
                message: String(localized: "Guides and AI are part of Premium", table: "Premium"),
                buttonTitle: String(localized: "Continue"),
                images: AdaptiveResources(iphone: Illustration.onbGuidebook.image),
                backgroundView: AnyView(
                    PremiumScreenBackground(kind: .onboarding, safeAreaTop: safeAreaTop) {
                        OnboardingFeatureScene(story: .guidance)
                    }
                )
            ),
        ]
    }

}
