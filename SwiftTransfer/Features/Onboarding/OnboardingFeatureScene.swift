import SwiftUI

struct OnboardingFeatureScene: View {
    enum Story {
        case transfer
        case selection
        case guidance

        var illustration: Illustration {
            switch self {
            case .transfer: .onbTransfer
            case .selection: .onbDataTypes
            case .guidance: .guideWifiGalaxy
            }
        }

        var eyebrow: LocalizedStringKey {
            switch self {
            case .transfer: "Your next chapter"
            case .selection: "You decide what moves"
            case .guidance: "A clearer way forward"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .transfer: "Your memories, together"
            case .selection: "Only what you choose"
            case .guidance: "A helpful next step"
            }
        }

        var detail: LocalizedStringKey {
            switch self {
            case .transfer: "Photos, contacts and more"
            case .selection: "Keep the rest on your old phone"
            case .guidance: "Guides and AI are part of Premium"
            }
        }

        var symbol: String {
            switch self {
            case .transfer: "arrow.triangle.2.circlepath"
            case .selection: "checkmark.circle.fill"
            case .guidance: "sparkles"
            }
        }
    }

    let story: Story
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var floating = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 360
            let width = max(0, min(520, proxy.size.width - 40))
            let cardHeight: CGFloat = compact ? 70 : 86
            let spacing: CGFloat = compact ? 10 : 16
            let heroHeight = max(
                80, min(330, proxy.size.height - cardHeight - 36 - spacing * 2 - 16))

            VStack(spacing: spacing) {
                eyebrow(compact: compact)
                hero(width: width, height: heroHeight)
                resultCard(compact: compact)
                    .frame(height: cardHeight)
                    .opacity(appeared || reduceMotion ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 6)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.32).delay(0.06), value: appeared)
            }
            .frame(width: width)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            appeared = true
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }

    private func eyebrow(compact: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: story.symbol)
            Text(story.eyebrow, tableName: "Premium")
        }
        .font(.system(size: compact ? 11 : 13, weight: .semibold))
        .foregroundStyle(AppColor.primaryDeep)
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 6 : 8)
        .background(.white.opacity(0.8), in: Capsule())
        .overlay { Capsule().stroke(AppColor.primary.opacity(0.12), lineWidth: 1) }
    }

    private func hero(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(AppColor.primary.opacity(0.055))
                .frame(width: height * 0.94, height: height * 0.94)
            Circle()
                .stroke(
                    AppColor.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 7])
                )
                .frame(width: height * 1.08, height: height * 1.08)
            story.illustration.image
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
                .offset(y: reduceMotion ? 0 : (floating ? -3 : 3))
                .scaleEffect(appeared || reduceMotion ? 1 : 0.97)
                .opacity(appeared || reduceMotion ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.32), value: appeared)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private func resultCard(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: story.symbol)
                .font(.system(size: compact ? 21 : 25, weight: .semibold))
                .foregroundStyle(AppColor.primary)
                .frame(width: compact ? 40 : 48, height: compact ? 40 : 48)
                .background(AppColor.skyMist, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(story.title, tableName: "Premium")
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(story.detail, tableName: "Premium")
                    .font(.system(size: compact ? 11 : 13))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppColor.primary.opacity(0.75))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, compact ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppColor.skyLight, lineWidth: 1) }
        .shadow(color: AppColor.primary.opacity(0.08), radius: 14, y: 6)
    }
}
