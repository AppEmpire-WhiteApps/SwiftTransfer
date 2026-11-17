import SwiftUI

/// Illustrative copy is deliberately labeled; replace it with approved feedback before release.
struct OnboardingReviews: View {
    var body: some View {
        ViewThatFits(in: .vertical) {
            cards.fixedSize(horizontal: false, vertical: true)
            ScrollView { cards }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.reviews")
    }

    private var cards: some View {
        VStack(spacing: 8) {
            review(
                title: "Photos, ready to move",
                body: "I picked the photos I wanted and moved them to my new phone over Wi-Fi.",
                symbol: "photo"
            )
            review(
                title: "A guide for each step",
                body: "The guide helped me connect my devices and choose what to transfer.",
                symbol: "book.closed"
            )
            review(
                title: "Help along the way",
                body: "I asked the assistant about my connection and got clear steps to try.",
                symbol: "bubble.left"
            )
        }
    }

    private func review(title: LocalizedStringKey, body: LocalizedStringKey, symbol: String)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            Text(body, tableName: "Premium")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: PremiumDesign.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: PremiumDesign.cornerRadius)
                .stroke(AppColor.skyLight, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
