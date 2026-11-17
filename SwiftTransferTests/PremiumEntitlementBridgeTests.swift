import Combine
import Observation
import PremiumKit
import SwiftData
import SwiftUI
import XCTest

@testable import SwiftTransfer

@MainActor
final class PremiumEntitlementBridgeTests: XCTestCase {
    func testActiveSubscriptionRefreshUnlocksSameLiveRouterAndModelsThenExpiryRelocks() async throws
    {
        let source = TestPremiumEntitlement()
        source.paywalls = [.main: paywall(.main, products: [product("subscription")])]
        let access = PremiumAccess(source: source)
        let router = AppRouter(access: access)
        let transfer = TransferFlowModel(start: .send(.android))
        transfer.premiumAccess = router.premiumAccess
        let export = DriveExportModel(access: router.premiumAccess)
        let restore = DriveRestoreModel(access: router.premiumAccess)
        let container = try ModelContainer(
            for: ChatThread.self, ChatMessage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let chat = ChatViewModel(
            thread: nil, client: MockLLMClient(delay: .zero), draft: "Keep draft", access: access)
        chat.attach(modelContext: container.mainContext, activity: nil)

        router.openGuide(.wifiGalaxy)
        chat.sendInput()
        XCTAssertEqual(router.guidesPath.count, 0)
        XCTAssertEqual(chat.input, "Keep draft")
        XCTAssertNil(chat.thread)
        XCTAssertFalse(transfer.premiumAccess.authorize(.photos))

        let invalidated = expectation(
            description: "Existing SwiftUI Observation dependency invalidates")
        withObservationTracking {
            _ = router.premiumAccess.isPremium
        } onChange: {
            invalidated.fulfill()
        }
        source.activeProductIds = ["subscription"]
        await fulfillment(of: [invalidated], timeout: 1)
        XCTAssertTrue(access.isPremium)
        XCTAssertFalse(source.isPremium, "Product-specific SDK access also shares app entitlement")
        router.openGuide(.wifiGalaxy)
        router.askAssistant(draft: "After subscription refresh")
        XCTAssertEqual(router.guidesPath.count, 1)
        XCTAssertEqual(router.assistantSheet?.draft, "After subscription refresh")
        for liveAccess in [
            transfer.premiumAccess, export.premiumAccess, restore.premiumAccess, chat.premiumAccess,
        ] {
            XCTAssertTrue(liveAccess === access)
            XCTAssertTrue(liveAccess.authorize(.photos))
            XCTAssertTrue(liveAccess.authorize(.assistant))
            XCTAssertTrue(liveAccess.authorize(.guides))
        }

        source.activeProductIds = []
        XCTAssertFalse(access.isPremium)
        router.assistantSheet = nil
        router.askAssistant(draft: "Expired")
        XCTAssertNil(router.assistantSheet)
        router.openGuide(.androidIphone)
        XCTAssertEqual(router.guidesPath.count, 1)
        chat.input = "Preserve expired draft"
        chat.sendInput()
        XCTAssertEqual(chat.input, "Preserve expired draft")
        XCTAssertNil(chat.thread)
        for liveAccess in [transfer.premiumAccess, export.premiumAccess, restore.premiumAccess] {
            XCTAssertFalse(liveAccess.authorize(.photos))
        }
    }

    func testUnknownAndConsumableIDsNeverConferSharedEntitlement() {
        let source = TestPremiumEntitlement()
        let access = PremiumAccess(source: source)
        source.activeProductIds = ["unknown", "tokens", "reused"]
        XCTAssertFalse(access.isPremium)
        source.paywalls = [
            .main: paywall(
                .main, products: [product("tokens", consumable: 100), product("reused")]),
            .consumable: paywall(.consumable, products: [product("reused", consumable: 20)]),
        ]
        XCTAssertFalse(access.isPremium)
        source.paywalls[PremiumRoute.assistant.paywallID] = paywall(
            PremiumRoute.assistant.paywallID, products: [product("assistantSubscription")])
        source.activeProductIds.insert("assistantSubscription")
        XCTAssertTrue(access.isPremium)
        source.activeProductIds.remove("assistantSubscription")
        XCTAssertFalse(access.isPremium)
        source.isPremium = true
        XCTAssertTrue(access.isPremium, "SDK's global Boolean remains authoritative")
        source.isPremium = false
        XCTAssertFalse(access.isPremium)
    }

    func testLateCatalogPublicationReevaluatesAlreadyActiveIDs() {
        let source = TestPremiumEntitlement()
        source.activeProductIds = ["subscription"]
        let access = PremiumAccess(source: source)
        XCTAssertFalse(access.isPremium)
        source.paywalls = [.onboarding: paywall(.onboarding, products: [product("subscription")])]
        XCTAssertTrue(access.isPremium)
        source.paywalls = [:]
        XCTAssertFalse(access.isPremium)
    }

    /// This is the SDK's native secondary-paywall long-press bypass, NOT a StoreKit purchase.
    /// It exercises the production singleton adapter and live SwiftUI observation end to end.
    func testNativeSDKScopedGrantUpdatesSameHostedUIAndRouterThenLogoutRelocks() async throws {
        guard PremiumSetup.isConfigured else { throw XCTSkip("Apphud configuration unavailable") }
        let sdk = Premium.shared
        guard !sdk.isPremium, sdk.activeProductIds.isEmpty else {
            throw XCTSkip(
                "Requires a clean, unsubscribed test process; won't overwrite paid account state")
        }
        let startup = PremiumStartup()
        await startup.prepareOnboarding()
        XCTAssertEqual(sdk.availablePaywall.id, .onboarding)
        let assistantID = PremiumRoute.assistant.paywallID
        let assistant = try XCTUnwrap(sdk.paywall(for: assistantID))
        XCTAssertFalse(assistant.products.isEmpty)
        await startup.prepareMain()
        XCTAssertEqual(sdk.availablePaywall.id, .main)

        let access = PremiumAccess()
        let router = AppRouter(access: access)
        let model = DriveExportModel(access: router.premiumAccess)
        let locked = expectation(description: "Hosted UI starts locked")
        let unlocked = expectation(description: "Existing hosted UI unlocks")
        let relocked = expectation(description: "Existing hosted UI relocks after SDK logout")
        var sawUnlocked = false
        let host = UIHostingController(
            rootView: EntitlementProbe { premium in
                if premium {
                    sawUnlocked = true
                    unlocked.fulfill()
                } else if sawUnlocked {
                    relocked.fulfill()
                } else {
                    locked.fulfill()
                }
            }.environment(router))
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            sdk.logout()
        }

        await fulfillment(of: [locked], timeout: 5)
        sdk.grantPremium(for: assistantID)
        XCTAssertFalse(sdk.isPremium, "Reproduces the SDK scoped-grant/global-Boolean discrepancy")
        XCTAssertTrue(access.isPremium)
        XCTAssertTrue(model.premiumAccess === router.premiumAccess)
        XCTAssertTrue(model.premiumAccess.authorize(.photos))
        router.askAssistant(draft: "Same router after native bypass")
        router.openGuide(.wifiGalaxy)
        XCTAssertEqual(router.guidesPath.count, 1)
        await fulfillment(of: [unlocked], timeout: 5)

        sdk.logout()
        XCTAssertFalse(access.isPremium)
        XCTAssertFalse(model.premiumAccess.authorize(.photos))
        await fulfillment(of: [relocked], timeout: 5)
    }

    private func product(_ id: String, consumable: Int? = nil) -> PremiumProduct {
        PremiumProduct(
            id: id, title: "Test", period: "week", pricePerPeriod: "$1", pricePerWeek: "$1",
            hasTrial: false, consumable: consumable)
    }

    private func paywall(_ id: PremiumPaywallID, products: [PremiumProduct]) -> PremiumPaywall {
        PremiumPaywall(
            id: id, title: "Test", configuration: .variant1,
            buttons: .init(tryFree: "Test", continue: "Test", purchase: "Test", limited: "Test"),
            products: products)
    }
}

@MainActor
private final class TestPremiumEntitlement: PremiumEntitlementSource {
    @Published var isPremium = false
    @Published var activeProductIds: Set<String> = []
    @Published var paywalls: [PremiumPaywallID: PremiumPaywall] = [:]

    var premiumChanges: AnyPublisher<Void, Never> {
        Publishers.Merge3(
            $isPremium.map { _ in () }, $activeProductIds.map { _ in () }, $paywalls.map { _ in () }
        ).eraseToAnyPublisher()
    }
}

private struct EntitlementProbe: View {
    @Environment(AppRouter.self) private var router
    let onChange: (Bool) -> Void

    var body: some View {
        Text(router.premiumAccess.isPremium ? "Unlocked" : "Locked")
            .onChange(of: router.premiumAccess.isPremium, initial: true) { _, value in
                onChange(value)
            }
    }
}
