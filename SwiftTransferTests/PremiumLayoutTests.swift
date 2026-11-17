import XCTest

@testable import SwiftTransfer

final class PremiumLayoutTests: XCTestCase {
    func testScaleClampsAcrossSupportedWindows() {
        let sizes: [CGSize] = [
            CGSize(width: 375, height: 647),
            CGSize(width: 440, height: 863),
            CGSize(width: 834, height: 1146),
            CGSize(width: 1194, height: 786),
            CGSize(width: 800, height: 552),
        ]
        for size in sizes {
            let layout = PremiumLayout(size: size)
            XCTAssertGreaterThanOrEqual(layout.scale, 0.85)
            XCTAssertLessThanOrEqual(layout.scale, 1.15)
        }
    }

    func testSharedCardRadiusDoesNotScale() {
        XCTAssertEqual(PremiumDesign.cornerRadius, 8)
    }

    func testSettingsBannerSwitchesPlacementAfterPurchaseAndExpiry() {
        XCTAssertEqual(SettingsPremiumBannerState(isPremium: false).route, .main)
        XCTAssertEqual(SettingsPremiumBannerState(isPremium: true).route, .assistant)
        XCTAssertEqual(SettingsPremiumBannerState(isPremium: false).route, .main)
    }

    func testAssistantPlacementMatchesSuppliedCatalog() {
        XCTAssertEqual(PremiumRoute.assistant.paywallID.rawValue, "aiChat")
    }

    func testFallbackManifestRejectsSDKPreviewAndUnknownProducts() {
        XCTAssertFalse(PremiumCatalogManifest.contains(["w", "m", "y", "l"], placement: "main"))
        XCTAssertFalse(PremiumCatalogManifest.contains([], placement: "onboarding"))
        XCTAssertFalse(PremiumCatalogManifest.contains(["unknown"], placement: "aiChat"))
        XCTAssertTrue(
            PremiumCatalogManifest.contains(
                ["app.Swift.Transfer.Week", "app.Swift.Transfer.WeekTrial"], placement: "onboarding"
            ))
    }
}
