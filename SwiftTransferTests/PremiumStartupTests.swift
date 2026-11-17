import PremiumKit
import XCTest

@testable import SwiftTransfer

@MainActor
final class PremiumStartupTests: XCTestCase {
    func testCompletedOnboardingLoadsAlwaysPlacementsOnlyOnce() async {
        let recorder = LoadRecorder()
        let startup = PremiumStartup(load: recorder.load)
        async let global: Void = startup.prepareAlways()
        async let branch: Void = startup.prepareMain()
        _ = await (global, branch)
        await startup.prepareMain()
        await startup.prepareAlways()

        XCTAssertEqual(recorder.loaded, [PremiumRoute.assistant.paywallID, .main])
        XCTAssertTrue(startup.isMainReady)
        XCTAssertFalse(startup.isOnboardingReady)
        XCTAssertEqual(recorder.available, .main)
    }

    func testUnfinishedOnboardingPreloadsAlwaysThenSelectsOnboarding() async {
        let recorder = LoadRecorder()
        let startup = PremiumStartup(load: recorder.load)
        async let global: Void = startup.prepareAlways()
        async let branch: Void = startup.prepareOnboarding()
        _ = await (global, branch)
        await startup.prepareOnboarding()
        await startup.prepareAlways()

        XCTAssertEqual(recorder.loaded, [PremiumRoute.assistant.paywallID, .main, .onboarding])
        XCTAssertTrue(startup.isOnboardingReady)
        XCTAssertFalse(startup.isMainReady)
        XCTAssertEqual(recorder.available, .onboarding)

        await startup.prepareMain()
        await startup.prepareMain()
        XCTAssertEqual(
            recorder.loaded, [PremiumRoute.assistant.paywallID, .main, .onboarding, .main])
        XCTAssertTrue(startup.isMainReady)
        XCTAssertEqual(recorder.available, .main)
    }

    func testRepeatedOnboardingReselectsEachFlowWithoutRepeatingAlwaysPreloads() async {
        let recorder = LoadRecorder()
        let startup = PremiumStartup(load: recorder.load)

        await startup.prepareMain()
        XCTAssertTrue(startup.isMainReady)
        XCTAssertFalse(startup.isOnboardingReady)
        for _ in 0..<2 {
            await startup.prepareOnboarding()
            await startup.prepareOnboarding()
            XCTAssertEqual(recorder.available, .onboarding)
            XCTAssertTrue(startup.isOnboardingReady)
            XCTAssertFalse(startup.isMainReady)

            await startup.prepareMain()
            await startup.prepareMain()
            XCTAssertEqual(recorder.available, .main)
            XCTAssertTrue(startup.isMainReady)
            XCTAssertFalse(startup.isOnboardingReady)
        }
        XCTAssertEqual(
            recorder.loaded,
            [PremiumRoute.assistant.paywallID, .main, .onboarding, .main, .onboarding, .main])
    }

    func testFastBranchTransitionWaitsForOnboardingBeforeSelectingMain() async {
        let recorder = LoadRecorder()
        recorder.pauseOnboarding = true
        let startup = PremiumStartup(load: recorder.load)
        let onboarding = Task { await startup.prepareOnboarding() }
        await recorder.waitForOnboarding()
        let main = Task { await startup.prepareMain() }
        XCTAssertFalse(startup.isOnboardingReady)
        XCTAssertFalse(startup.isMainReady)
        recorder.finishOnboarding()
        await onboarding.value
        await main.value

        XCTAssertTrue(startup.isMainReady)
        XCTAssertEqual(recorder.available, .main)
        XCTAssertEqual(
            recorder.loaded, [PremiumRoute.assistant.paywallID, .main, .onboarding, .main])
    }

    func testBranchCancellationDoesNotLeaveTaskOncePermanentlyUnready() async {
        let recorder = LoadRecorder()
        recorder.pauseOnboarding = true
        let startup = PremiumStartup(load: recorder.load)
        let branch = Task { await startup.prepareOnboarding() }
        await recorder.waitForOnboarding()
        branch.cancel()
        recorder.finishOnboarding()
        await branch.value
        await startup.prepareOnboarding()

        XCTAssertTrue(startup.isOnboardingReady)
        XCTAssertEqual(recorder.loaded, [PremiumRoute.assistant.paywallID, .main, .onboarding])
    }
}

@MainActor
private final class LoadRecorder {
    var loaded: [PremiumPaywallID] = []
    var available: PremiumPaywallID?
    var pauseOnboarding = false
    private var started = false
    private var startedWaiter: CheckedContinuation<Void, Never>?
    private var resumeOnboarding: CheckedContinuation<Void, Never>?

    func load(_ id: PremiumPaywallID) async {
        loaded.append(id)
        if id.isAvailablePaywall { available = id }
        if id == .onboarding, pauseOnboarding {
            await withCheckedContinuation { continuation in
                resumeOnboarding = continuation
                started = true
                startedWaiter?.resume()
                startedWaiter = nil
            }
        }
    }

    func waitForOnboarding() async {
        if started { return }
        await withCheckedContinuation { startedWaiter = $0 }
    }

    func finishOnboarding() {
        resumeOnboarding?.resume()
        resumeOnboarding = nil
    }
}
