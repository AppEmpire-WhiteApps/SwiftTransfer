import Combine
import SwiftUI
import XCTest

@testable import SwiftTransfer

@MainActor
final class PremiumBannerRenderingTests: XCTestCase {
    func testBannerRendersBothLiveSubscriptionStates() throws {
        let entitlement = CurrentValueSubject<Bool, Never>(false)
        let access = PremiumAccess(entitlement: entitlement.eraseToAnyPublisher())
        let router = AppRouter(access: access)
        let before = try render(router, name: "settings-banner-free")
        XCTAssertEqual(SettingsPremiumBannerState(isPremium: access.isPremium).route, .main)

        entitlement.send(true)
        let after = try render(router, name: "settings-banner-subscribed")
        XCTAssertEqual(SettingsPremiumBannerState(isPremium: access.isPremium).route, .assistant)
        XCTAssertNotEqual(before.data, after.data)

        entitlement.send(false)
        XCTAssertEqual(SettingsPremiumBannerState(isPremium: access.isPremium).route, .main)
    }

    func testBannerRendersEnglishAndRussianAtPhoneAndSettingsColumnWidths() throws {
        for isPremium in [false, true] {
            let entitlement = CurrentValueSubject<Bool, Never>(isPremium)
            let access = PremiumAccess(entitlement: entitlement.eraseToAnyPublisher())
            let router = AppRouter(access: access)
            let state = isPremium ? "assistant" : "premium"

            for language in ["en", "ru"] {
                for width: CGFloat in [320, 375, 760] {
                    let image = try render(
                        router,
                        name: "settings-\(state)-\(language)-\(Int(width))",
                        width: width,
                        locale: Locale(identifier: language)
                    )
                    XCTAssertEqual(image.size.width, width, accuracy: 1)
                    XCTAssertGreaterThanOrEqual(image.size.height, 192)
                    XCTAssertLessThanOrEqual(image.size.height, 240, "Keep default text compact")
                }
            }
        }
    }

    func testBannerGrowsForAccessibilityTextInBothLanguages() throws {
        for isPremium in [false, true] {
            let entitlement = CurrentValueSubject<Bool, Never>(isPremium)
            let access = PremiumAccess(entitlement: entitlement.eraseToAnyPublisher())
            let router = AppRouter(access: access)
            let state = isPremium ? "assistant" : "premium"

            for language in ["en", "ru"] {
                let standard = try render(
                    router,
                    name: "settings-\(state)-\(language)-standard",
                    width: 320,
                    locale: Locale(identifier: language)
                )
                let accessible = try render(
                    router,
                    name: "settings-\(state)-\(language)-accessibility5",
                    width: 320,
                    locale: Locale(identifier: language),
                    dynamicTypeSize: .accessibility5
                )
                XCTAssertEqual(accessible.size.width, standard.size.width, accuracy: 1)
                XCTAssertGreaterThan(accessible.size.height, standard.size.height)
            }
        }
    }

    private func render(
        _ router: AppRouter,
        name: String,
        width: CGFloat = 375,
        locale: Locale = Locale(identifier: "en"),
        dynamicTypeSize: DynamicTypeSize = .large
    ) throws -> (data: Data, size: CGSize) {
        let renderer = ImageRenderer(
            content: SettingsPremiumBanner()
                .environment(router)
                .environment(\.locale, locale)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
                .frame(maxWidth: 720)
                .padding(20)
                .frame(width: width)
                .background(AppColor.background)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return (try XCTUnwrap(image.pngData()), image.size)
    }
}
