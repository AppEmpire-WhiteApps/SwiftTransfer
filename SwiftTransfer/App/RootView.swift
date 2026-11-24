import PremiumKit
import SwiftUI

struct RootView: View {
    @AppStorage(SettingsKey.onboardingCompleted) private var onboardingCompleted = false
    @State private var startup = PremiumStartup()

    var body: some View {
        Group {
            if onboardingCompleted {
                MainTabView()
                    .transition(.opacity)
                    .taskOnce {
                        await startup.prepareMain()
                    }
            } else {
                OnboardingView {
                    withAnimation(.easeInOut) {
                        onboardingCompleted = true
                    }
                }
                .modifier(OnboardingStartupSplash(startup: startup))
            }
        }
        .taskOnce {
            await startup.prepareAssistant()
        }
    }
}

private struct OnboardingStartupSplash: ViewModifier {
    let startup: PremiumStartup
    @State private var isShowingSplash = true

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isShowingSplash)
            .accessibilityHidden(isShowingSplash)
            .overlay {
                if isShowingSplash {
                    SplashView()
                }
            }
            .taskOnce {
                await startup.prepareOnboarding()
                await MainActor.run { isShowingSplash = false }
            }
            .task(id: isShowingSplash) {
                guard isShowingSplash else { return }
                // A stalled SDK request must not block entry into onboarding.
                do {
                    try await Task.sleep(for: .seconds(5))
                    isShowingSplash = false
                } catch {
                    return
                }
            }
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView()
                    .appRouteDestinations()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack(path: $router.guidesPath) {
                GuidesView()
                    .appRouteDestinations()
            }
            .tabItem {
                Label("Guides", systemImage: "book")
            }
            .tag(AppTab.guides)

            AssistantTabView()
                .tabItem {
                    Label("Assistant", systemImage: "sparkles")
                }
                .tag(AppTab.assistant)

            NavigationStack(path: $router.settingsPath) {
                SettingsView()
                    .appRouteDestinations()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(AppColor.primary)
        .fullScreenCover(item: $router.transferFlow) { start in
            TransferFlowView(start: start)
        }
        // While the transfer flow is open it presents the assistant sheet itself.
        .sheet(item: rootAssistantSheet) { launch in
            AssistantSheetView(launch: launch)
        }
        .premiumPresentation(active: router.transferFlow == nil && router.assistantSheet == nil)
    }

    private var rootAssistantSheet: Binding<AssistantLaunch?> {
        Binding(
            get: { router.transferFlow == nil ? router.assistantSheet : nil },
            set: { router.assistantSheet = $0 }
        )
    }
}
