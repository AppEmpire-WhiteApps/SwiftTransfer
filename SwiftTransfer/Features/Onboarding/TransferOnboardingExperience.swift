import PremiumKit
import SwiftUI

struct TransferOnboardingExperience: View {
    let onFinish: () -> Void
    @State private var page = 0
    var body: some View {
        GeometryReader { proxy in
            OnboardingBuilder(
                screens: screens,
                paywallImages: PremiumDesign.resources,
                style: PremiumDesign.onboarding(scale: PremiumLayout(size: proxy.size).scale),
                linksConfig: PremiumDesign.links,
                isTrialEnabled: false,
                showReviewRequestOnComplete: false,
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
                onScreenShown: { index, _ in page = index },
                onPaywallShown: { page = 3 },
                onSecondaryPaywallShown: { page = 4 },
                onComplete: onFinish
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.\(page)")
    }

    private var screens: [OnboardingScreen] {
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
                    PremiumScreenBackground(kind: .onboarding) {
                        OnboardingFeatureScene(illustration: .onbTransfer)
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
                    PremiumScreenBackground(kind: .onboarding) {
                        OnboardingFeatureScene(illustration: .onbDataTypes)
                    }
                )
            ),
            OnboardingScreen(
                id: 2,
                title1: String(localized: "A smoother move", table: "Premium"),
                title2: String(localized: "In their words", table: "Premium"),
                subtitle: String(
                    localized:
                        "A look at everyday transfer stories\nIllustrative reviews for this preview",
                    table: "Premium"),
                message: String(localized: "Photos, guidance and a helping hand", table: "Premium"),
                buttonTitle: String(localized: "Continue"),
                images: PremiumDesign.resources,
                backgroundView: AnyView(
                    PremiumScreenBackground(kind: .onboarding) {
                        OnboardingReviews()
                    }
                )
            ),
        ]
    }

}

private struct OnboardingFeatureScene: View {
    let illustration: Illustration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        GeometryReader { proxy in
            let height = max(60, min(420, proxy.size.height - 24, proxy.size.width * 0.9))
            IllustrationView(illustration: illustration, height: height, floating: true)
                .scaleEffect(visible || reduceMotion ? 1 : 0.97)
                .opacity(visible || reduceMotion ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 20)
                .onAppear {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.36)) {
                        visible = true
                    }
                }
        }
        .id(illustration.rawValue)
    }
}

#Preview("SE") {
    TransferOnboardingExperience {}
        .frame(width: 375, height: 667)
}

#Preview("Large iPhone") {
    TransferOnboardingExperience {}
        .frame(width: 440, height: 956)
}

#Preview("iPad portrait") {
    TransferOnboardingExperience {}
        .frame(width: 834, height: 1194)
}

#Preview("iPad landscape") {
    TransferOnboardingExperience {}
        .frame(width: 1194, height: 834)
}

#Preview("Unfolded window") {
    TransferOnboardingExperience {}
        .frame(width: 800, height: 600)
}
