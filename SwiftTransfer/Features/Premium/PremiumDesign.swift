import PremiumKit
import SwiftUI

enum PremiumDesign {
    static let cornerRadius: CGFloat = 8
    static let resources = AdaptiveResources(iphone: Image("paywall_transfer"))
    static let assistantResources = AdaptiveResources(iphone: Image("paywall_assistant"))

    static var links: LinksConfiguration {
        LinksConfiguration(
            termsTitle: String(localized: "Terms of Use", table: "Premium"),
            privacyTitle: String(localized: "Privacy Policy", table: "Premium"),
            restoreTitle: String(localized: "Restore", table: "Premium"),
            order: [.terms, .restore, .privacy]
        )
    }

    static func onboarding(scale: CGFloat) -> OnboardingStyle {
        OnboardingStyle(
            limitedButtonColor: AppColor.textSecondary,
            backgroundColor: AppGradient.hero,
            titleFont: .system(size: 26 * scale, weight: .bold),
            title1Color: AppColor.textPrimary,
            title2Color: AppColor.textPrimary,
            subtitleFont: .system(size: 15 * scale),
            subtitleColor: AppColor.textSecondary,
            messageFont: .system(size: 14 * scale),
            messageColor: AppColor.textPrimary,
            messageBackgroundColor: AppColor.skyMist,
            messageHeight: 48 * scale,
            messageCornerRadius: cornerRadius,
            messageBorderColor: AppColor.skyLight,
            messageShowBorder: true,
            buttonFont: .system(size: 18 * scale, weight: .semibold),
            buttonTextColor: Color.white,
            buttonBackgroundColor: AppColor.primary,
            buttonCornerRadius: cornerRadius,
            buttonHeight: 52 * scale,
            showPaywallButtonAnimation: false,
            linksFont: .system(size: 12 * scale),
            linksColor: AppColor.textSecondary,
            linksShowDividers: false,
            contentSpacing: 12 * scale,
            horizontalPadding: 20,
            bottomPadding: 8,
            maxWidth: 520,
            indicatorActiveColor: AppColor.primary,
            indicatorInactiveColor: AppColor.skyLight,
            indicatorFutureColor: AppColor.skyLight,
            indicatorActiveWidth: 24,
            indicatorInactiveWidth: 8,
            indicatorHeight: 8,
            indicatorSpacing: 8,
            showNewToggle: true,
            toggleType: .checkmark,
            checkmarkActiveBGColor: AppColor.primary,
            checkmarkInactiveBorderColor: AppColor.primary,
            minimumScaleFactor: 0.8
        )
    }

    static func main(scale: CGFloat) -> PaywallStyle {
        PaywallStyle(
            accentColor: AppColor.primary,
            backgroundColor: AppGradient.hero,
            titleOrder: .titleFirst,
            titleFont: .system(size: 25 * scale, weight: .bold),
            titleColor: AppColor.textPrimary,
            subtitleFont: .system(size: 14 * scale),
            subtitleColor: AppColor.textSecondary,
            titleSubtitleSpacing: 4,
            buttonFont: .system(size: 18 * scale, weight: .semibold),
            buttonTextColor: Color.white,
            buttonBackgroundColor: AppColor.primary,
            buttonCornerRadius: cornerRadius,
            buttonHeight: 52 * scale,
            linksFont: .system(size: 12 * scale),
            linksColor: AppColor.textSecondary,
            linksShowDividers: false,
            contentSpacing: 12 * scale,
            horizontalPadding: 20,
            bottomPadding: 8,
            maxWidth: 520,
            offerHeight: 52 * scale,
            offerCornerRadius: cornerRadius,
            offerSpacing: 6 * scale,
            offerTitleFont: .system(size: 15 * scale, weight: .semibold),
            offerTitleColor: AppColor.textPrimary,
            offerSelectedTitleFont: .system(size: 15 * scale, weight: .semibold),
            offerSelectedTitleColor: AppColor.textPrimary,
            offerSubtitleFont: .system(size: 12 * scale),
            offerSubtitleColor: AppColor.textSecondary,
            offerSelectedSubtitleFont: .system(size: 12 * scale),
            offerSelectedSubtitleColor: AppColor.textSecondary,
            offerPriceFont: .system(size: 14 * scale, weight: .semibold),
            offerPriceColor: AppColor.textPrimary,
            offerSelectedPriceFont: .system(size: 14 * scale, weight: .semibold),
            offerSelectedPriceColor: AppColor.textPrimary,
            offerBorderColor: AppColor.divider,
            offerSelectedBorderColor: AppColor.primary,
            offerBorderWidth: 1,
            offerSelectedBorderWidth: 1,
            offerBackgroundColor: AppColor.surface,
            offerSelectedBackgroundColor: AppColor.skyMist,
            offerCheckmarkActiveBGColor: AppColor.primary,
            closeButtonIcon: "xmark",
            closeButtonColor: AppColor.textSecondary,
            closeButtonFont: .system(size: 14, weight: .semibold),
            closeButtonPlacement: .topBarTrailing,
            closeButtonShowGlass: false
        )
    }

    static func assistant(scale: CGFloat) -> SecondaryPaywallStyle {
        var style = SecondaryPaywallStyle()
        style.contentBackground.backgroundColor = AnyShapeStyle(AppGradient.hero)
        style.title.font = .system(size: 26 * scale, weight: .bold)
        style.title.color1 = AnyShapeStyle(AppColor.textPrimary)
        style.title.color2 = AnyShapeStyle(AppColor.textPrimary)
        style.title.subtitleFont = .system(size: 15 * scale)
        style.title.subtitleColor = AnyShapeStyle(AppColor.textSecondary)
        style.title.minimumScaleFactor = 0.8
        style.messageToggle.backgroundColor = AnyShapeStyle(AppColor.skyMist)
        style.messageToggle.color = AnyShapeStyle(AppColor.textPrimary)
        style.messageToggle.font = .system(size: 14 * scale)
        style.messageToggle.height = 48 * scale
        style.messageToggle.cornerRadius = cornerRadius
        style.messageToggle.showBorder = true
        style.messageToggle.borderColor = AnyShapeStyle(AppColor.skyLight)
        style.messageToggle.showNewToggle = true
        style.messageToggle.checkmarkActiveBGColor = AnyShapeStyle(AppColor.primary)
        style.messageToggle.checkmarkInactiveBorderColor = AnyShapeStyle(AppColor.primary)
        style.button.backgroundColor = AnyShapeStyle(AppColor.primary)
        style.button.textColor = AnyShapeStyle(Color.white)
        style.button.font = .system(size: 18 * scale, weight: .semibold)
        style.button.cornerRadius = cornerRadius
        style.button.height = 52 * scale
        style.links.font = .system(size: 12 * scale)
        style.links.color = AnyShapeStyle(AppColor.textSecondary)
        style.links.showDividers = false
        style.layout.contentSpacing = 12 * scale
        style.layout.horizontalPadding = 20
        style.layout.bottomPadding = 8
        style.layout.maxWidth = 520
        style.offer.cornerRadius = cornerRadius
        style.offer.height = 52 * scale
        style.offer.selectedBorderColor = AnyShapeStyle(AppColor.primary)
        style.offer.selectedBackgroundColor = AnyShapeStyle(AppColor.skyMist)
        style.closeButton.color = AnyShapeStyle(AppColor.textSecondary)
        style.closeButton.placement = .topBarTrailing
        style.closeButton.showGlass = false
        return style
    }
}

struct PremiumLayout {
    let size: CGSize

    var scale: CGFloat { min(1.15, max(0.85, size.height / 780)) }

}
