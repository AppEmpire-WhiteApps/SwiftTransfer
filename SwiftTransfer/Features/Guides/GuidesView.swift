import SwiftUI

/// S10: grid of guide covers with search and an FAQ accordion.
struct GuidesView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var query = ""

    private var guides: [Guide] {
        GuideLibrary.search(query).filter { $0.id != .faq }
    }

    private var faqItems: [GuideFAQItem] {
        GuideLibrary.searchFAQ(query)
    }

    private var columns: [GridItem] {
        let minimum: CGFloat = sizeClass == .regular ? 220 : 150
        return [GridItem(.adaptive(minimum: minimum), spacing: Spacing.l, alignment: .top)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                if query.isEmpty {
                    intro
                }
                if !guides.isEmpty {
                    LazyVGrid(columns: columns, spacing: Spacing.l) {
                        ForEach(guides) { guide in
                            Button {
                                router.openGuide(guide.id)
                            } label: {
                                GuideGridCard(guide: guide)
                                    .overlay(alignment: .topTrailing) {
                                        if !router.premiumAccess.isPremium {
                                            Image(systemName: "lock.fill")
                                                .foregroundStyle(AppColor.primary)
                                                .padding(12)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("guide.\(guide.id.rawValue)")
                        }
                    }
                }
                if !faqItems.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        SectionHeader(title: "Frequently asked questions")
                        GuideFAQList(items: faqItems)
                    }
                }
                if guides.isEmpty && faqItems.isEmpty {
                    EmptyStateView(
                        illustration: .guideFAQ,
                        title: "Nothing found",
                        message: "Try another word or ask the assistant."
                    )
                }
            }
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .screenBackground()
        .navigationTitle("Guides")
        .searchable(text: $query, prompt: Text("Search guides"))
        .trackScreen("guides")
    }

    private var intro: some View {
        HStack(alignment: .center, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Step-by-step help")
                    .font(AppFont.title2)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Short illustrated guides for every way to move your data.")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            IllustrationView(illustration: .guideFAQ, height: 84, glow: false)
        }
        .cardStyle(background: AppColor.skyMist)
    }
}

/// Cover card of a guide in the grid.
private struct GuideGridCard: View {
    let guide: Guide

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            guide.cover.image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .padding(Spacing.s)
                .background(AppGradient.hero, in: RoundedRectangle(cornerRadius: Radius.small + 4, style: .continuous))
                .accessibilityHidden(true)
            Text(guide.title)
                .font(AppFont.callout.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Label {
                Text("≈ \(guide.minutes) min")
            } icon: {
                Image(systemName: "clock")
            }
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: Radius.card - 4, style: .continuous))
        .shadow(color: AppColor.primary.opacity(0.08), radius: 12, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card - 4, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the guide"))
    }
}

/// Accordion of FAQ items in cards.
struct GuideFAQList: View {
    @Environment(AppRouter.self) private var router
    let items: [GuideFAQItem]
    @State private var expanded: Set<UUID> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.m) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Button {
                        toggle(item.id)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                            Text(item.question)
                                .font(AppFont.headline)
                                .foregroundStyle(AppColor.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if !router.premiumAccess.isPremium {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(AppColor.primary)
                            }
                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppColor.primary)
                                .rotationEffect(.degrees(expanded.contains(item.id) ? 180 : 0))
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(Text(expanded.contains(item.id) ? "Expanded" : "Collapsed"))
                    .accessibilityHint(Text("Shows the answer"))

                    if expanded.contains(item.id) && router.premiumAccess.isPremium {
                        Text(item.answer)
                            .font(AppFont.callout)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                .cardStyle()
            }
        }
    }

    private func toggle(_ id: UUID) {
        guard router.premiumAccess.authorize(.guides) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            if expanded.contains(id) {
                expanded.remove(id)
            } else {
                expanded.insert(id)
            }
        }
    }
}

#Preview("Guides") {
    NavigationStack {
        GuidesView()
            .appRouteDestinations()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}

#Preview("FAQ") {
    ScrollView {
        GuideFAQList(items: GuideLibrary.guide(.faq).faq)
            .padding()
    }
    .screenBackground()
    .environment(AppRouter())
}
