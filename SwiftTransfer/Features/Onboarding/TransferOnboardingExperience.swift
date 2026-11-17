import PremiumKit
import SwiftUI

struct TransferOnboardingExperience: View {
    let onFinish: () -> Void
    @StateObject private var controller = OnboardingController()
    @State private var page = 0
    @State private var loaded = false
    @State private var catalogReady = false
    @State private var legalDocument: PremiumLegalDocument?
    @State private var restoreUnavailable = false

    var body: some View {
        GeometryReader { proxy in
            let layout = PremiumLayout(size: proxy.size)
            Group {
                if !PremiumSetup.isConfigured || loaded {
                    builder(layout: layout)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(AppGradient.hero.ignoresSafeArea())
        .task {
            guard PremiumSetup.isConfigured else { return }
            catalogReady = await PremiumCatalog.load(.onboarding)
            loaded = true
        }
        .overlay(alignment: .bottom) {
            if !PremiumSetup.isConfigured {
                unconfiguredFooter
            }
        }
        .sheet(item: $legalDocument) { document in
            PremiumLegalScreen(document: document)
        }
        .alert(Text("Restore", tableName: "Premium"), isPresented: $restoreUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "Subscriptions are currently unavailable. Please try again later.",
                tableName: "Premium")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.\(page)")
    }

    private func builder(layout: PremiumLayout) -> some View {
        OnboardingBuilder(
            screens: screens,
            paywallImages: PremiumDesign.resources,
            style: PremiumDesign.onboarding(scale: layout.scale),
            paywallHideContent: catalogReady
                ? [] : [.indicators, .title, .subtitle, .message, .button],
            linksConfig: onboardingLinks,
            isTrialEnabled: false,
            showReviewRequestOnComplete: false,
            termsView: { PremiumLegalScreen(document: .terms) },
            privacyView: { PremiumLegalScreen(document: .privacy) },
            paywallBackgroundView: AnyView(AppGradient.hero),
            paywallMiddleView: AnyView(paywallContent),
            controller: controller,
            onScreenShown: { index, _ in page = index },
            onPaywallShown: { page = 3 },
            onComplete: onFinish
        )
    }

    private var paywallContent: some View {
        VStack(spacing: 16) {
            PremiumArtwork(route: .main)
            if !catalogReady {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(0..<4) { index in
                            Capsule()
                                .fill(index == 3 ? AppColor.primary : AppColor.skyLight)
                                .frame(width: index == 3 ? 24 : 8, height: 8)
                        }
                    }
                    .accessibilityHidden(true)
                    Text("Unlock your next move", tableName: "Premium")
                        .font(AppFont.title2)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(
                        "Subscriptions are currently unavailable. Please try again later.",
                        tableName: "Premium"
                    )
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    Button {
                        controller.skip()
                    } label: {
                        Text("Continue with limited access", tableName: "Premium")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                AppColor.primary,
                                in: RoundedRectangle(cornerRadius: PremiumDesign.cornerRadius))
                    }
                    .accessibilityIdentifier("onboarding.limited")
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
            }
        }
    }

    private var onboardingLinks: LinksConfiguration {
        guard !PremiumSetup.isConfigured else { return PremiumDesign.links }
        return LinksConfiguration(termsTitle: "", privacyTitle: "", restoreTitle: "", order: [])
    }

    private var unconfiguredFooter: some View {
        HStack(spacing: 16) {
            Button(PremiumDesign.links.termsTitle) { legalDocument = .terms }
            Button(PremiumDesign.links.restoreTitle) { restoreUnavailable = true }
            Button(PremiumDesign.links.privacyTitle) { legalDocument = .privacy }
        }
        .font(.system(size: 12))
        .foregroundStyle(AppColor.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: 520)
        .frame(height: 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
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
                images: PremiumDesign.resources,
                backgroundView: AnyView(AppGradient.hero),
                middleView: AnyView(OnboardingFeatureScene(illustration: .onbTransfer))
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
                images: PremiumDesign.resources,
                backgroundView: AnyView(AppGradient.hero),
                middleView: AnyView(OnboardingFeatureScene(illustration: .onbDataTypes))
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
                backgroundView: AnyView(AppGradient.hero),
                middleView: AnyView(OnboardingReviews())
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
