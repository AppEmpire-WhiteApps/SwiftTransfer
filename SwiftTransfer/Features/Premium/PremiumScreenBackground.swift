import SwiftUI

/// Artwork occupies only the space above the builder's native payment controls.
struct PremiumScreenBackground<Content: View>: View {
    let kind: PremiumBackgroundKind
    var safeAreaTop: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let layout = PremiumBackgroundLayout(size: proxy.size, kind: kind)
            let topPadding = max(layout.topPadding, safeAreaTop + 8)
            let sceneHeight = max(
                0, min(600, proxy.size.height - layout.reservedBottom - topPadding - 20))
            VStack(spacing: 0) {
                content()
                    .frame(width: proxy.size.width, height: sceneHeight)
                Spacer(minLength: 0)
            }
            .padding(.top, topPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background {
            switch kind {
            case .onboarding:
                AppGradient.hero.ignoresSafeArea()
            case .main:
                PremiumAmbientBackground(assistant: false)
            case .assistant:
                PremiumAmbientBackground(assistant: true)
            }
        }
    }
}

private struct PremiumAmbientBackground: View {
    let assistant: Bool

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(900, proxy.size.width * 1.4)
            ZStack {
                AppGradient.hero
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppColor.primary.opacity(0.24), .clear],
                            center: .center, startRadius: 0, endRadius: diameter / 2)
                    )
                    .frame(width: diameter, height: diameter)
                    .position(x: proxy.size.width * 0.18, y: proxy.size.height * 0.17)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (assistant ? Color.indigo : Color.cyan).opacity(0.18), .clear,
                            ],
                            center: .center, startRadius: 0, endRadius: diameter / 2)
                    )
                    .frame(width: diameter, height: diameter)
                    .position(x: proxy.size.width * 0.96, y: proxy.size.height * 0.32)
                Ellipse()
                    .stroke(.white.opacity(0.65), lineWidth: 1)
                    .frame(width: diameter * 0.9, height: diameter * 0.55)
                    .rotationEffect(.degrees(-24))
                    .position(x: proxy.size.width * 0.48, y: proxy.size.height * 0.23)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.25),
                        .init(color: .white.opacity(0.55), location: 0.62),
                        .init(color: .white, location: 0.88),
                    ], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum PremiumBackgroundKind {
    case onboarding
    case main
    case assistant
}

struct PremiumBackgroundLayout {
    let size: CGSize
    let kind: PremiumBackgroundKind

    var topPadding: CGFloat { 24 }

    var reservedBottom: CGFloat {
        let scale = PremiumLayout(size: size).scale
        switch kind {
        case .onboarding:
            return 350 * scale
        case .main:
            return 410 * scale
        case .assistant:
            return 330 * scale
        }
    }

    var sceneHeight: CGFloat {
        max(0, min(600, size.height - reservedBottom - topPadding - 20))
    }
}
