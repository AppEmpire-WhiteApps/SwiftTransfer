import XCTest

extension XCUIApplication {
    func selectPremiumTestTab(_ title: String) {
        // iPad's floating tabs have no TabBar ancestor in the accessibility tree.
        let tab = buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        guard tab.waitForExistence(timeout: 30) else {
            XCTFail("Missing native tab: \(title)")
            return
        }
        // iOS 27 can expose native tabs as PopUpButton to AX and return a -1 hit point.
        // Tap the element's visible center rather than invoking that AX hit-point resolver.
        tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    var nativePremiumCTA: XCUIElement {
        buttons.matching(
            NSPredicate(
                format: "label IN %@",
                [
                    "Continue", "Try free & subscribe", "Continue & subscribe",
                    "Purchase & continue",
                ])
        ).firstMatch
    }

    var nativePremiumClose: XCUIElement {
        let candidates = buttons.matching(
            NSPredicate(format: "label IN %@", ["Close", "Закрыть", "xmark"]))
        return candidates.allElementsBoundByIndex.first(where: { $0.isHittable })
            ?? candidates.firstMatch
    }
}
