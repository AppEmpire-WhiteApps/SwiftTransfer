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
        XCTAssertNotEqual(before, after)

        entitlement.send(false)
        XCTAssertEqual(SettingsPremiumBannerState(isPremium: access.isPremium).route, .main)
    }

    private func render(_ router: AppRouter, name: String) throws -> Data {
        let renderer = ImageRenderer(
            content: SettingsPremiumBanner()
                .environment(router)
                .padding(20)
                .frame(width: 375)
                .background(AppColor.background)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return try XCTUnwrap(image.pngData())
    }
}
