import SwiftUI

/// A single tappable card for the main or assistant paywall placement.
struct SettingsPremiumBanner: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAssistant: Bool {
        router.premiumAccess.isPremium
    }

    private var route: PremiumRoute {
        SettingsPremiumBannerState(isPremium: isAssistant).route
    }

    private var heading: LocalizedStringKey {
        isAssistant ? "Your AI transfer assistant" : "Premium access"
    }

    private var benefit: LocalizedStringKey {
        isAssistant
            ? "Get answers and guidance while you transfer."
            : "Transfer photos and follow step-by-step guides."
    }

    private var callToAction: LocalizedStringKey {
        isAssistant ? "Explore AI assistant" : "Explore Premium"
    }

    private var illustrationName: String {
        isAssistant ? "paywall_assistant" : "paywall_transfer"
    }

    var body: some View {
        Button {
            // Open the placement even when the shared subscription is active.
            // This is navigation only; it does not change feature entitlements.
            router.premiumAccess.paywallRoute = route
        } label: {
            HStack(alignment: .center, spacing: Spacing.l) {
                copy
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !dynamicTypeSize.isAccessibilitySize {
                    Image(illustrationName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .padding(Spacing.s)
                        .background(
                            .white.opacity(0.12),
                            in: RoundedRectangle(
                                cornerRadius: Radius.card,
                                style: .continuous
                            )
                        )
                        .accessibilityHidden(true)
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColor.primaryDeep, AppColor.primaryPressed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: AppColor.primary.opacity(0.18), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            isAssistant ? "settings.assistantBanner" : "settings.premiumBanner")
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Image(systemName: isAssistant ? "sparkles" : "crown.fill")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)

                Text(heading, tableName: "Premium")
                    .font(AppFont.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(benefit, tableName: "Premium")
                .font(AppFont.callout)
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(callToAction, tableName: "Premium")
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "arrow.forward")
                    .accessibilityHidden(true)
            }
            .font(AppFont.footnote.weight(.semibold))
            .padding(.top, Spacing.xs)
        }
        .multilineTextAlignment(.leading)
    }
}

struct SettingsPremiumBannerState {
    let isPremium: Bool

    var route: PremiumRoute { isPremium ? .assistant : .main }
}
