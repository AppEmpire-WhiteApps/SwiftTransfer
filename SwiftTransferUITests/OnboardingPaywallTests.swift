import XCTest

@MainActor
final class OnboardingPaywallTests: XCTestCase {
    private func launchOnboarding(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ResetOnboarding", "-ForcePremiumFallback",
            "-AppleLanguages", "(\(language))", "-AppleLocale",
            language == "ru" ? "ru_RU" : "en_US",
        ]
        app.launch()
        return app
    }

    private func next(_ app: XCUIApplication, language: String = "en") {
        let button = app.buttons[language == "ru" ? "Продолжить" : "Continue"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 30))
        button.tap()
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testThirdScreenHasThreeLabeledReviewsThenPaywall() {
        let app = launchOnboarding()
        capture(app, name: "onboarding-first")
        next(app)
        next(app)
        XCTAssertTrue(app.otherElements["onboarding.reviews"].waitForExistence(timeout: 30))
        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "Photos, ready to move")
            )
            .firstMatch.exists)
        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "A guide for each step")
            )
            .firstMatch.exists)
        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "Help along the way")
            )
            .firstMatch.exists)
        capture(app, name: "onboarding-three-reviews")
        next(app)
        let limited = app.buttons["Or proceed with limited version"]
        XCTAssertTrue(limited.waitForExistence(timeout: 30))
        capture(app, name: "onboarding-native-paywall")
        limited.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 30))
        app.terminate()
        app.launchArguments = ["-DisablePremium", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 30))
    }

    func testInterruptedOnboardingStartsAgain() {
        let app = launchOnboarding()
        next(app)
        next(app)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ResetOnboarding" }
        app.launch()
        XCTAssertTrue(app.staticTexts["Move to a new phone"].waitForExistence(timeout: 30))
    }

    func testSettingsBannerPresentsMainArtworkAndLegalScreens() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ForcePremiumFallback", "-onboardingCompleted", "YES", "-OpenScreen", "settings",
            "-AppleLanguages", "(en)",
        ]
        app.launch()
        let banner = app.buttons["settings.premiumBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 30))
        capture(app, name: "settings-premium-banner")
        banner.tap()
        XCTAssertTrue(app.otherElements["paywall.main"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Unlimited access!"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["premium.unavailable"].exists)
        XCTAssertTrue(app.nativePremiumCTA.isHittable)
        capture(app, name: "main-paywall-artwork")
        app.otherElements["paywall.main"].buttons["Terms of Use"].tap()
        XCTAssertTrue(app.navigationBars["Terms of Use"].waitForExistence(timeout: 30))
        capture(app, name: "terms-screen")
    }

    func testRussianReviewPage() {
        let app = launchOnboarding(language: "ru")
        next(app, language: "ru")
        next(app, language: "ru")
        XCTAssertTrue(app.otherElements["onboarding.reviews"].waitForExistence(timeout: 30))
        capture(app, name: "onboarding-reviews-ru")
    }

    func testReviewsAndLimitedActionRemainReachableAfterRotation() {
        let app = launchOnboarding()
        next(app)
        next(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let continueButton = app.buttons["Continue"].firstMatch
        XCTAssertTrue(continueButton.waitForExistence(timeout: 30))
        XCTAssertTrue(continueButton.isHittable)
        capture(app, name: "onboarding-reviews-landscape")
        continueButton.tap()
        let limited = app.buttons["Or proceed with limited version"]
        XCTAssertTrue(limited.waitForExistence(timeout: 30))
        XCTAssertTrue(limited.isHittable)
        capture(app, name: "onboarding-paywall-landscape")
    }
}
