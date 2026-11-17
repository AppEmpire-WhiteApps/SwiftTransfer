import XCTest

@MainActor
final class PremiumIntegrationTests: XCTestCase {
    func testNormalCatalogLoadsAllPlacements() {
        inspectCatalog(forceFallback: false)
    }

    func testForcedFallbackLoadsAllPlacements() {
        inspectCatalog(forceFallback: true)
    }

    func testConfiguredMainAndAssistantBuildersPresent() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboardingCompleted", "YES", "-OpenScreen", "settings",
            "-ForcePremiumFallback", "-AppleLanguages", "(en)",
        ]
        app.launch()
        let banner = app.buttons["settings.premiumBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 30))
        banner.tap()
        XCTAssertTrue(app.staticTexts["Unlimited access!"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["premium.unavailable"].exists)
        capture(app, name: "configured-main-builder")
        app.nativePremiumClose.tap()
        app.descendants(matching: .any)["Assistant"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["paywall.assistant"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Unlock"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["premium.unavailable"].exists)
        capture(app, name: "configured-assistant-builder")
    }

    func testConfiguredOnboardingSkipsWithoutOpeningAssistantPaywall() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ResetOnboarding", "-ForcePremiumFallback", "-AppleLanguages", "(en)",
        ]
        app.launch()
        for _ in 0..<3 {
            let next = app.buttons["Continue"].firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 30))
            next.tap()
        }
        let limited = app.buttons["Or proceed with limited version"]
        XCTAssertTrue(limited.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Unlock"].exists)
        capture(app, name: "configured-onboarding-paywall")
        limited.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.otherElements["paywall.assistant"].exists)
        app.terminate()
        app.launchArguments = ["-ForcePremiumFallback", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 30))
    }

    func testNativeSecondaryEntitlementUnlocksLiveSettingsAndGuides() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboardingCompleted", "YES", "-OpenScreen", "settings",
            "-ForcePremiumFallback", "-AppleLanguages", "(en)",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["settings.premiumBanner"].waitForExistence(timeout: 30))
        app.selectPremiumTestTab("Assistant")
        XCTAssertTrue(app.otherElements["paywall.assistant"].waitForExistence(timeout: 30))
        // Exercise the SDK's own debug access gesture, not a billed purchase.
        XCTAssertTrue(app.nativePremiumClose.waitForExistence(timeout: 30))
        app.nativePremiumClose.press(forDuration: 10.5)
        app.selectPremiumTestTab("Settings")
        XCTAssertTrue(app.buttons["settings.assistantBanner"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["settings.premiumBanner"].exists)
        capture(app, name: "settings-native-secondary-access")
        app.selectPremiumTestTab("Guides")
        let guide = app.buttons["guide.wifi_galaxy"]
        XCTAssertTrue(guide.waitForExistence(timeout: 30))
        guide.tap()
        XCTAssertFalse(app.otherElements["paywall.main"].waitForExistence(timeout: 1))
        XCTAssertTrue(
            app.buttons["Ask the assistant about this guide"].waitForExistence(timeout: 30))
        capture(app, name: "guide-unlocked-after-sdk-entitlement")
    }

    func testRepeatedOnboardingReturnsToNativeMainCatalog() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ResetOnboarding", "-ForcePremiumFallback", "-AppleLanguages", "(en)",
        ]
        app.launch()
        for round in 0..<2 {
            for _ in 0..<3 {
                let next = app.buttons["Continue"].firstMatch
                XCTAssertTrue(next.waitForExistence(timeout: 30))
                next.tap()
            }
            let limited = app.buttons["Or proceed with limited version"]
            XCTAssertTrue(limited.waitForExistence(timeout: 30))
            limited.tap()
            app.selectPremiumTestTab("Settings")
            let banner = app.buttons["settings.premiumBanner"]
            XCTAssertTrue(banner.waitForExistence(timeout: 30))
            banner.tap()
            XCTAssertTrue(app.staticTexts["Unlimited access!"].waitForExistence(timeout: 30))
            XCTAssertTrue(
                app.buttons.containing(.staticText, identifier: "Life time deal").firstMatch.exists)
            app.nativePremiumClose.tap()
            if round == 0 {
                app.buttons.containing(.staticText, identifier: "Show onboarding again").firstMatch
                    .tap()
                XCTAssertTrue(app.staticTexts["Move to a new phone"].waitForExistence(timeout: 30))
            }
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func inspectCatalog(forceFallback: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-PremiumIntegrationCheck", "-AppleLanguages", "(en)"]
        if forceFallback { app.launchArguments.append("-ForcePremiumFallback") }
        app.launch()
        let complete = app.staticTexts["Catalog inspection complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 90))
        let models = app.staticTexts.matching(identifier: "premium.snapshot")
            .allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(models.count, 3)
        let expected: [(String, [String])] = [
            ("onboarding", ["app.Swift.Transfer.Week", "app.Swift.Transfer.WeekTrial"]),
            (
                "main",
                [
                    "app.Swift.Transfer.WeekTrial", "app.Swift.Transfer.Month",
                    "app.Swift.Transfer.Year", "app.Swift.Transfer.Lifetime",
                ]
            ),
            ("aiChat", ["app.Swift.Transfer.WeekAi", "app.Swift.Transfer.WeekTrialAi"]),
        ]
        for (placement, ids) in expected {
            let snapshot = models.first { $0.hasPrefix(placement + " | ") }
            XCTAssertNotNil(snapshot, placement)
            XCTAssertTrue(
                snapshot?.hasSuffix(ids.joined(separator: ",")) == true, snapshot ?? placement)
            XCTAssertTrue(snapshot?.contains("variant1") == true, snapshot ?? placement)
        }
        let snapshot = XCTAttachment(string: models.joined(separator: "\n"))
        snapshot.name = forceFallback ? "forced-fallback-models" : "normal-models"
        snapshot.lifetime = .keepAlways
        add(snapshot)
    }
}
