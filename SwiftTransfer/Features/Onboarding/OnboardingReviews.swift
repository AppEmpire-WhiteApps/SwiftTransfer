import SwiftUI

/// The names and quotes are design examples, not verified customer testimonials.
struct OnboardingReviews: View {
    @ScaledMetric(relativeTo: .footnote) private var bodySize = 12

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 380
            ViewThatFits(in: .vertical) {
                composition(compact: compact).fixedSize(horizontal: false, vertical: true)
                ScrollView { composition(compact: compact) }
            }
            .frame(width: min(520, max(0, proxy.size.width - 40)))
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.reviews")
    }

    private func composition(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 14) {
            endorsement(compact: compact)
            EqualReviewCards(spacing: compact ? 6 : 8) {
                review(
                    name: "Alex", initial: "A", title: "Photos, ready to move",
                    body: "My photos arrived on my new phone over Wi-Fi.", compact: compact)
                review(
                    name: "Sam", initial: "S", title: "A guide for each step",
                    body: "The guide made connecting my phones much clearer.", compact: compact)
                review(
                    name: "Jordan", initial: "J", title: "Help along the way",
                    body: "The assistant helped me work out what to try next.", compact: compact)
            }
        }
    }

    private func endorsement(compact: Bool) -> some View {
        HStack(spacing: compact ? 18 : 24) {
            Image(systemName: "laurel.leading")
            VStack(spacing: compact ? 3 : 5) {
                stars(size: compact ? 9 : 12)
                VStack(spacing: 0) {
                    Text("Built around", tableName: "Premium")
                    Text("Your next move", tableName: "Premium")
                }
                .font(.system(size: compact ? 15 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            }
            Image(systemName: "laurel.trailing")
        }
        .font(.system(size: compact ? 27 : 38, weight: .medium))
        .foregroundStyle(AppColor.primary)
    }

    private func review(
        name: String, initial: String, title: LocalizedStringKey,
        body: LocalizedStringKey, compact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 8) {
                Text(verbatim: initial)
                    .font(.system(size: compact ? 13 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.primaryDeep)
                    .frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
                    .background(AppGradient.hero, in: Circle())
                    .overlay { Circle().stroke(AppColor.skyLight, lineWidth: 1) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(verbatim: name)
                            .font(.system(size: compact ? 12 : 14, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text("Example", tableName: "Premium")
                            .font(.system(size: compact ? 10 : 11))
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer(minLength: 4)
                        stars(size: compact ? 8 : 10)
                    }
                    Text(title, tableName: "Premium")
                        .font(.system(size: compact ? 11 : 12, weight: .medium))
                        .foregroundStyle(AppColor.primaryDeep)
                }
            }
            Text(body, tableName: "Premium")
                .font(.system(size: compact ? bodySize : bodySize + 1).italic())
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 7 : 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppColor.skyLight, lineWidth: 1) }
        .shadow(color: AppColor.primary.opacity(0.045), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }

    private func stars(size: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill") }
        }
        .font(.system(size: size))
        .foregroundStyle(AppColor.warning)
        .accessibilityLabel(Text("Example rating: five stars", tableName: "Premium"))
    }
}

/// Measure the complete wrapped copy before assigning the same height to each card.
private struct EqualReviewCards: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let height =
            subviews.map {
                $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            }.max() ?? 0
        return CGSize(
            width: width, height: height * CGFloat(subviews.count) + totalSpacing(subviews.count))
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }
        let height = (bounds.height - totalSpacing(subviews.count)) / CGFloat(subviews.count)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + CGFloat(index) * (height + spacing)),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: height))
        }
    }

    private func totalSpacing(_ count: Int) -> CGFloat {
        spacing * CGFloat(max(0, count - 1))
    }
}
