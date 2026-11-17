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
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        banner.tap()
        XCTAssertTrue(app.staticTexts["Unlimited access!"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["premium.unavailable"].exists)
        capture(app, name: "configured-main-builder")
        app.buttons["premium.close"].tap()
        app.descendants(matching: .any)["Assistant"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["paywall.assistant"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["paywall.assistant"].exists)
        app.terminate()
        app.launchArguments = ["-ForcePremiumFallback", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
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
