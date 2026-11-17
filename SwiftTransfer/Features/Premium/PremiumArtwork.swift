import SwiftUI

struct PremiumArtwork: View {
    let route: PremiumRoute
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var floating = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 250
            let width = max(0, min(680, proxy.size.width - 40))
            let cardHeight: CGFloat = compact ? 64 : 80
            let spacing: CGFloat = compact ? 8 : 14
            let heroHeight = max(60, proxy.size.height - cardHeight - spacing - 28)
            VStack(spacing: spacing) {
                hero(width: width, height: heroHeight)
                HStack(spacing: 8) {
                    if route == .main {
                        benefit("Photo transfer", symbol: "photo.on.rectangle", compact: compact)
                        benefit("Transfer guides", symbol: "book.closed", compact: compact)
                        benefit("AI assistant", symbol: "sparkles", compact: compact)
                    } else {
                        benefit(
                            "Transfer help", symbol: "bubble.left.and.bubble.right",
                            compact: compact)
                        benefit(
                            "Clear next steps", symbol: "list.bullet.clipboard", compact: compact)
                    }
                }
                .frame(width: min(520, width))
                .opacity(appeared || reduceMotion ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.32).delay(0.06), value: appeared)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                appeared = true
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                    floating = true
                }
            }
        }
    }

    private func hero(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(.white.opacity(0.65))
                .overlay { Ellipse().stroke(.white.opacity(0.9), lineWidth: 1) }
                .frame(width: width * 0.82, height: max(18, height * 0.14))
                .shadow(color: AppColor.primary.opacity(0.14), radius: 20, y: 10)
                .offset(y: height * 0.30)
            Ellipse()
                .stroke(.white.opacity(0.7), lineWidth: 1)
                .frame(width: width * 0.96, height: height * 0.72)
                .rotationEffect(.degrees(-14))
            Image(route == .main ? "paywall_transfer" : "paywall_assistant")
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
                .shadow(color: AppColor.primaryDeep.opacity(0.10), radius: 14, y: 8)
                .offset(y: reduceMotion ? 0 : (floating ? -2 : 2))
                .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
                .opacity(appeared || reduceMotion ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.34), value: appeared)
            Image(systemName: "sparkle")
                .font(.system(size: min(23, height * 0.1), weight: .medium))
                .foregroundStyle(AppColor.primary.opacity(0.45))
                .offset(x: width * 0.36, y: -height * 0.25)
            Image(systemName: "sparkle")
                .font(.system(size: min(15, height * 0.07), weight: .medium))
                .foregroundStyle(.white)
                .offset(x: -width * 0.35, y: height * 0.12)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private func benefit(_ title: LocalizedStringKey, symbol: String, compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 13 : 17, weight: .semibold))
                .foregroundStyle(AppColor.primary)
                .frame(width: compact ? 24 : 32, height: compact ? 24 : 32)
                .background(AppColor.skyMist, in: Circle())
                .overlay { Circle().stroke(.white, lineWidth: 1) }
            Text(title, tableName: "Premium")
                .lineLimit(2, reservesSpace: true)
        }
        .font(.system(size: compact ? 11 : 13, weight: .semibold))
        .foregroundStyle(AppColor.primaryDeep)
        .multilineTextAlignment(.center)
        .padding(.horizontal, compact ? 6 : 10)
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 64 : 80)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.white, AppColor.skyMist.opacity(0.85)], startPoint: .topLeading,
                        endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.95), lineWidth: 1.5)
        }
        .shadow(color: AppColor.primaryDeep.opacity(0.09), radius: 10, y: 5)
    }
}

#Preview("Compact") {
    PremiumArtwork(route: .main)
        .frame(width: 375, height: 200)
        .background(AppGradient.hero)
}

#Preview("Wide") {
    PremiumArtwork(route: .assistant)
        .frame(width: 1194, height: 340)
        .background(AppGradient.hero)
}
