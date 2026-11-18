import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \TransferRecord.date, order: .reverse) private var records: [TransferRecord]

    var body: some View {
        ScrollView {
            Group {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: Spacing.xxl) {
                        HomeHeroCard()
                            .frame(maxWidth: .infinity)
                        VStack(spacing: Spacing.xxl) {
                            sections
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: Spacing.xxl) {
                        HomeHeroCard()
                        sections
                    }
                }
            }
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .screenBackground()
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.open(.history)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel(Text("History"))
            }
        }
        .trackScreen("home")
    }

    @ViewBuilder
    private var sections: some View {
        CategoriesSection()
        MethodsSection()
        ConnectionCheckCard()
        AssistantBanner()
        GuidesCarousel()
        if let last = records.first {
            LastTransferCard(record: last)
        }
    }
}

// MARK: - Hero

private struct HomeHeroCard: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: Spacing.l) {
            IllustrationView(illustration: .heroPhones, height: 210, floating: true)
            VStack(spacing: Spacing.s) {
                Text("Move data to your new phone")
                    .font(AppFont.title1)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Move contacts, photos, videos and calendars between iPhone and Android, or back up data to an external drive.")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: Spacing.m) {
                Button {
                    router.startTransfer(.send(nil))
                } label: {
                    Label("Send data", systemImage: "arrow.up.right")
                }
                .buttonStyle(.primary)

                Button {
                    router.startTransfer(.receive(nil))
                } label: {
                    Label("Receive data", systemImage: "arrow.down.left")
                }
                .buttonStyle(.secondary)
            }
        }
        .padding(Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: Radius.card + 4, style: .continuous)
                .fill(LinearGradient(
                    colors: [AppColor.skyLight, AppColor.surface],
                    startPoint: .top,
                    endPoint: .bottom
                ))
        }
        .shadow(color: AppColor.primary.opacity(0.10), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Categories

private struct CategoriesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "What you can move")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.m) {
                    ForEach(DataCategory.allCases) { category in
                        CategoryIconTile(category: category)
                    }
                }
                .padding(.vertical, Spacing.s)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Methods

private struct MethodsSection: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Ways to transfer")
            MethodCard(
                illustration: .methodWifi,
                title: "Wi-Fi and QR code",
                subtitle: "To any Android phone through its browser — no app needed there."
            ) {
                router.startTransfer(.send(.android))
            }
            MethodCard(
                illustration: .methodCable,
                title: "Cable and drive",
                subtitle: "Save to a USB drive or follow the wired transfer guide."
            ) {
                router.open(.externalStorage)
            }
        }
    }
}

private struct MethodCard: View {
    let illustration: Illustration
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.l) {
                illustration.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 72)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(subtitle)
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
            }
            .cardStyle(padding: Spacing.m)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Connection check & assistant

private struct ConnectionCheckCard: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.open(.connectionCheck)
        } label: {
            HStack(spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Connection check")
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Wi-Fi, permissions, speed, battery and free space in 15 seconds.")
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Run check")
                        .font(AppFont.callout.weight(.semibold))
                        .foregroundStyle(AppColor.primary)
                        .padding(.top, Spacing.xs)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Illustration.connectionCheck.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 90)
            }
            .cardStyle(background: AppColor.skyMist)
        }
        .buttonStyle(.plain)
    }
}

private struct AssistantBanner: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.selectedTab = .assistant
        } label: {
            HStack(spacing: Spacing.m) {
                Illustration.assistantAvatar.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask the assistant")
                        .font(AppFont.headline)
                        .foregroundStyle(.white)
                    Text("It helps at every step of the transfer.")
                        .font(AppFont.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .padding(Spacing.l)
            .background(AppGradient.primary, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .shadow(color: AppColor.primary.opacity(0.25), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Guides

private struct GuidesCarousel: View {
    @Environment(AppRouter.self) private var router

    private let featured: [GuideID] = [.wifiGalaxy, .cableGalaxy, .androidIphone, .storage, .notTransferable]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Guides", actionTitle: "All") {
                router.selectedTab = .guides
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.m) {
                    ForEach(featured) { guide in
                        Button {
                            router.openGuide(guide)
                        } label: {
                            GuideCoverCard(guide: guide)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Spacing.s)
            }
            .scrollClipDisabled()
        }
    }
}

private struct GuideCoverCard: View {
    let guide: GuideID

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            guide.cover.image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .background(AppColor.skyMist, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            Text(guide.title)
                .font(AppFont.callout.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2, reservesSpace: true)
            Label {
                Text("≈ \(guide.minutes) min")
            } icon: {
                Image(systemName: "clock")
            }
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
        }
        .padding(Spacing.m)
        .frame(width: 200)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: Radius.card - 4, style: .continuous))
        .shadow(color: AppColor.primary.opacity(0.07), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Last transfer

private struct LastTransferCard: View {
    let record: TransferRecord
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Last transfer")
            Button {
                router.open(.history)
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: record.status == .completed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(record.status == .completed ? AppColor.success : AppColor.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.method.title)
                            .font(AppFont.headline)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(record.totalBytes.formatted(.byteCount(style: .file)))")
                            .font(AppFont.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .cardStyle()
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
    .modelContainer(for: [TransferRecord.self, ChatThread.self, ChatMessage.self], inMemory: true)
}
