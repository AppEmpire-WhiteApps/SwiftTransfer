import PremiumKit
import SwiftUI

/// An artwork-backed banner for the main or assistant paywall placement.
struct SettingsPremiumBanner: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var premium = Premium.shared

    private var isAssistant: Bool {
        route == .assistant
    }

    private var route: PremiumRoute? {
        SettingsPremiumBannerState(
            isPremium: router.premiumAccess.isPremium,
            hasAssistantSubscription: premium.hasActiveProduct(
                fromPaywall: PremiumRoute.assistant.paywallID)
        ).route
    }

    private var heading: LocalizedStringKey {
        isAssistant ? "AI assistant" : "Premium access"
    }

    private var benefit: LocalizedStringKey {
        isAssistant
            ? "Get answers and guidance while you transfer."
            : "Transfer photos and follow step-by-step guides."
    }

    private var illustrationName: String {
        isAssistant ? "paywall_assistant" : "paywall_transfer"
    }

    private var artworkInset: CGFloat {
        // Give larger text the full width instead of shrinking or truncating it.
        dynamicTypeSize >= .xxxLarge ? 0 : 100
    }

    var body: some View {
        if let route {
            Button {
                // Open the placement even when the shared subscription is active.
                // This is navigation only; it does not change feature entitlements.
                router.premiumAccess.paywallRoute = route
            } label: {
                copy
                    .padding(Spacing.xl)
                    .padding(.trailing, artworkInset)
                    .frame(maxWidth: .infinity, minHeight: 152, alignment: .leading)
                    .background { artworkBackground }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(AppColor.primary.opacity(0.10), lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .shadow(color: AppColor.primary.opacity(0.07), radius: 12, x: 0, y: 5)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(
                isAssistant ? "settings.assistantBanner" : "settings.premiumBanner")
        }
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(heading, tableName: "Premium")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)

                Image(systemName: "arrow.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
                    .accessibilityHidden(true)
            }

            Text(benefit, tableName: "Premium")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artworkBackground: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                LinearGradient(
                    colors: [AppColor.surface, AppColor.skyMist, AppColor.skyLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                if !dynamicTypeSize.isAccessibilitySize {
                    Image(illustrationName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: min(geometry.size.width * 0.62, 340),
                            height: geometry.size.height
                        )
                        .clipped()
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white, location: 0.35),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                        .opacity(artworkInset == 0 ? 0.16 : 1)
                }

                // The artwork belongs to the whole banner; this scrim keeps copy clear.
                LinearGradient(
                    stops: [
                        .init(color: AppColor.surface, location: 0),
                        .init(color: AppColor.surface.opacity(0.97), location: 0.46),
                        .init(color: AppColor.surface.opacity(0.75), location: 0.62),
                        .init(color: AppColor.surface.opacity(0), location: 0.82),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct SettingsPremiumBannerState {
    let isPremium: Bool
    let hasAssistantSubscription: Bool

    var route: PremiumRoute? {
        guard !hasAssistantSubscription else { return nil }
        return isPremium ? .assistant : .main
    }
}
