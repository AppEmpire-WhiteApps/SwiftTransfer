import SwiftUI

struct PremiumPaywallScreen: View {
    let route: PremiumRoute
    @Environment(AppRouter.self) private var router

    var body: some View {
        TransferPaywallContent(route: route) {
            router.premiumAccess.paywallRoute = nil
        }
    }
}

private struct PremiumPresentation: ViewModifier {
    @Environment(AppRouter.self) private var router
    @State private var presentedRoute: PremiumRoute?
    let active: Bool

    func body(content: Content) -> some View {
        content
            .fullScreenCover(
                item: $presentedRoute,
                onDismiss: {
                    if active { router.premiumAccess.paywallRoute = nil }
                }
            ) { route in
                PremiumPaywallScreen(route: route)
            }
            .onChange(of: active ? router.premiumAccess.paywallRoute : nil, initial: true) { _, route in
                presentedRoute = route
            }
    }
}

private struct PremiumLockModifier: ViewModifier {
    let locked: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .blur(radius: locked ? 16 : 0)
            .allowsHitTesting(!locked)
            .accessibilityHidden(locked)
            .overlay {
                if locked {
                    Button(action: action) {
                        ZStack {
                            AppColor.background.opacity(0.25)
                            Image(systemName: "lock.fill")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(AppColor.primary)
                                .padding(18)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Available with a subscription"))
                }
            }
            .clipped()
    }
}

extension View {
    func premiumPresentation(active: Bool = true) -> some View {
        modifier(PremiumPresentation(active: active))
    }

    func premiumLocked(_ locked: Bool, action: @escaping () -> Void) -> some View {
        modifier(PremiumLockModifier(locked: locked, action: action))
    }
}
