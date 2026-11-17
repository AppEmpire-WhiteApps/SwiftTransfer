import SwiftUI

/// Artwork occupies only the space above the builder's native payment controls.
struct PremiumScreenBackground<Content: View>: View {
    let kind: PremiumBackgroundKind
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let layout = PremiumBackgroundLayout(size: proxy.size, kind: kind)
            VStack(spacing: 0) {
                content()
                    .frame(height: layout.sceneHeight)
                Spacer(minLength: 0)
            }
            .padding(.top, layout.topPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(AppGradient.hero.ignoresSafeArea())
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
