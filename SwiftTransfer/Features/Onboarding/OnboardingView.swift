import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        TransferOnboardingExperience(onFinish: onFinish)
            .trackScreen("onboarding")
    }
}

#Preview {
    OnboardingView {}
        .environment(AppActivityContext())
}
