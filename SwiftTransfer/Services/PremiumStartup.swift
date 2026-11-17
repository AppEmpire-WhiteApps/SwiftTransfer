import Foundation
import PremiumKit

/// Owns startup loading, not presentation. The SDK's main/onboarding selection is global,
/// so those loads must finish in order.
@MainActor
final class PremiumStartup {
    private enum Flow {
        case main
        case onboarding
    }

    private let load: @MainActor (PremiumPaywallID) async -> Void
    private var alwaysTask: Task<Void, Never>?
    private var activeFlow: Flow?
    private var flowTask: Task<Void, Never>?

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

        let task = Task { @MainActor in
            // Serialize even rapid/repeated Settings → onboarding → main transitions.
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
        }
        flowTask = task
        await task.value
    }

    private static func loadPaywall(_ id: PremiumPaywallID) async {
        guard PremiumSetup.isConfigured else { return }
        await Premium.shared.loadPaywall(id)
        // PremiumKit delivers its final paywalls dictionary with receive(on: main).
        // Drain those already-enqueued publications before the next placement load.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}
