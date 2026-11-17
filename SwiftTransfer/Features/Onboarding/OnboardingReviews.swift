import SwiftUI

/// Illustrative copy is deliberately labeled; replace it with approved feedback before release.
struct OnboardingReviews: View {
    @ScaledMetric(relativeTo: .footnote) private var compactBodySize = 12
    @ScaledMetric(relativeTo: .subheadline) private var compactTitleSize = 13

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 360
            ViewThatFits(in: .vertical) {
                cards(compact: compact).fixedSize(horizontal: false, vertical: true)
                ScrollView { cards(compact: compact) }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.reviews")
    }

    private func cards(compact: Bool) -> some View {
        EqualReviewCards(spacing: 8) {
            review(
                title: "Photos, ready to move",
                body: "I picked the photos I wanted and moved them to my new phone over Wi-Fi.",
                symbol: "photo", compact: compact
            )
            review(
                title: "A guide for each step",
                body: "The guide helped me connect my devices and choose what to transfer.",
                symbol: "book.closed", compact: compact
            )
            review(
                title: "Help along the way",
                body: "I asked the assistant about my connection and got clear steps to try.",
                symbol: "bubble.left", compact: compact
            )
        }
    }

    private func review(
        title: LocalizedStringKey, body: LocalizedStringKey, symbol: String, compact: Bool
    )
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                    .frame(width: 24, height: 24)
                    .background(AppColor.skyMist, in: Circle())
                    .accessibilityHidden(true)
                Text("Illustrative review", tableName: "Premium")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(AppColor.warning)
                .accessibilityLabel(Text("Example rating: five stars", tableName: "Premium"))
            }
            Text(title, tableName: "Premium")
                .font(
                    compact
                        ? .system(size: compactTitleSize, weight: .semibold)
                        : .subheadline.weight(.semibold)
                )
                .foregroundStyle(AppColor.textPrimary)
            Text(body, tableName: "Premium")
                .font(compact ? .system(size: compactBodySize) : .footnote)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 8 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: PremiumDesign.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: PremiumDesign.cornerRadius)
                .stroke(AppColor.skyLight, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
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
                proposal: ProposedViewSize(width: bounds.width, height: height)
            )
        }
    }

    private func totalSpacing(_ count: Int) -> CGFloat {
        spacing * CGFloat(max(0, count - 1))
    }
}
