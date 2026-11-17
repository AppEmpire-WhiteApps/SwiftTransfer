import SwiftUI

struct PremiumArtwork: View {
    let route: PremiumRoute
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 250
            VStack(spacing: compact ? 4 : 12) {
                Image(route == .main ? "paywall_transfer" : "paywall_assistant")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 680, maxHeight: .infinity)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.96)
                    .opacity(appeared || reduceMotion ? 1 : 0)
                    .accessibilityHidden(true)

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
                .frame(maxWidth: 520)
                .opacity(appeared || reduceMotion ? 1 : 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, compact ? 0 : 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.38)) {
                    appeared = true
                }
            }
        }
    }

    private func benefit(_ title: LocalizedStringKey, symbol: String, compact: Bool) -> some View {
        Label {
            Text(title, tableName: "Premium")
        } icon: {
            Image(systemName: symbol)
        }
        .font(.system(size: compact ? 12 : 14, weight: .medium))
        .foregroundStyle(AppColor.primaryDeep)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, compact ? 8 : 12)
        .frame(maxWidth: .infinity)
        .background(
            .white.opacity(0.92), in: RoundedRectangle(cornerRadius: PremiumDesign.cornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PremiumDesign.cornerRadius)
                .stroke(AppColor.skyLight, lineWidth: 1)
        }
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
