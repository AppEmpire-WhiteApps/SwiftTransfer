import Foundation
import Observation
import PremiumKit

/// Owns startup loading, not presentation. The SDK's main/onboarding selection is global,
/// so those loads must finish in order before either builder is constructed.
@MainActor
@Observable
final class PremiumStartup {
    private enum Flow {
        case main
        case onboarding
    }

    private(set) var isOnboardingReady = false
    private(set) var isMainReady = false

    @ObservationIgnored private let load: @MainActor (PremiumPaywallID) async -> Void
    @ObservationIgnored private var alwaysTask: Task<Void, Never>?
    @ObservationIgnored private var activeFlow: Flow?
    @ObservationIgnored private var flowTask: Task<Void, Never>?
    @ObservationIgnored private var flowGeneration = 0

    init(load: @escaping @MainActor (PremiumPaywallID) async -> Void = PremiumStartup.loadPaywall) {
        self.load = load
    }

    /// Required on every launch, including launches into unfinished onboarding.
    func prepareAlways() async {
        if let alwaysTask {
            await alwaysTask.value
            return
        }
        let task = Task { @MainActor in
            await load(PremiumRoute.assistant.paywallID)
            await load(.main)
        }
        alwaysTask = task
        await task.value
    }

    /// Called only by the unfinished-onboarding branch's native taskOnce.
    func prepareOnboarding() async {
        await prepare(.onboarding)
    }

    func prepareMain() async {
        await prepare(.main)
    }

    private func prepare(_ flow: Flow) async {
        if activeFlow == flow, let flowTask {
            await flowTask.value
            return
        }

        let previousTask = flowTask
        let needsMainActivation = activeFlow != nil
        activeFlow = flow
        flowGeneration += 1
        let generation = flowGeneration
        isOnboardingReady = false
        isMainReady = false

        let task = Task { @MainActor in
            // Serialize even rapid/repeated Settings → onboarding → main transitions.
            // An old flow may finish loading, but must not mark the new flow ready.
            await previousTask?.value
            await prepareAlways()
            switch flow {
            case .onboarding:
                await load(.onboarding)
            case .main:
                if needsMainActivation {
                    // The SDK has no public select-cached-paywall API. Activate main
                    // once per branch transition, never per paywall appearance.
                    await load(.main)
                }
            }
            guard generation == flowGeneration else { return }
            isOnboardingReady = flow == .onboarding
            isMainReady = flow == .main
        }
        flowTask = task
        await task.value
    }

    private static func loadPaywall(_ id: PremiumPaywallID) async {
        guard PremiumSetup.isConfigured else { return }
        await Premium.shared.loadPaywall(id)
        // PremiumKit delivers its final paywalls dictionary with receive(on: main).
        // Drain those already-enqueued publications before constructing a builder whose
        // view model captures availablePaywall only at initialization.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}
