import SwiftUI

/// Section title with an optional trailing action.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.title2)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppFont.callout.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Capsule chip, e.g. quick questions or assistant actions.
struct Chip: View {
    let title: Text
    var systemImage: String?
    var isSelected = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
            }
            title
                .font(AppFont.callout.weight(.medium))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(isSelected ? .white : AppColor.primaryDeep)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(minHeight: 36)
        .background(
            isSelected ? AnyShapeStyle(AppGradient.primary) : AnyShapeStyle(AppColor.skyLight),
            in: Capsule()
        )
    }
}

/// Empty/error state with an illustration, title, message and optional action.
struct EmptyStateView: View {
    let illustration: Illustration
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.l) {
            IllustrationView(illustration: illustration, height: 180, floating: true)
            VStack(spacing: Spacing.s) {
                Text(title)
                    .font(AppFont.title2)
                    .foregroundStyle(AppColor.textPrimary)
                Text(message)
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
                    .frame(maxWidth: 320)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

/// Expanding rings around a central view, used while searching/waiting for a device.
struct PulseRings: View {
    var color: Color = AppColor.primary
    var ringCount = 3
    var duration: Double = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 2)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<ringCount, id: \.self) { index in
                        let phase = ((time / duration) + Double(index) / Double(ringCount))
                            .truncatingRemainder(dividingBy: 1)
                        Circle()
                            .stroke(color.opacity(0.45 * (1 - phase)), lineWidth: 2)
                            .scaleEffect(0.35 + 0.65 * phase)
                    }
                }
            }
        }
    }
}

/// Floating assistant avatar button for transfer screens.
struct AssistantFloatingButton: View {
    var draft: String?
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.askAssistant(draft: draft)
        } label: {
            Illustration.assistantAvatar.image
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: AppColor.primary.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel(Text("Ask the assistant"))
    }
}

/// Card with a 3D category icon and its title.
struct CategoryIconTile: View {
    let category: DataCategory

    var body: some View {
        VStack(spacing: Spacing.s) {
            category.illustration.image
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 56)
            Text(category.title)
                .font(AppFont.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 92, height: 104)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: Radius.small + 6, style: .continuous))
        .shadow(color: AppColor.primary.opacity(0.07), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            SectionHeader(title: "What you can move", actionTitle: "All") {}
            HStack {
                Chip(title: Text("How to move photos?"))
                Chip(title: Text("Selected"), systemImage: "checkmark", isSelected: true)
            }
            CategoryIconTile(category: .photos)
            ZStack {
                PulseRings()
                    .frame(width: 240, height: 240)
                IllustrationView(illustration: .connectSearching, height: 140, glow: false)
            }
            EmptyStateView(
                illustration: .emptyHistory,
                title: "No transfers yet",
                message: "Your transfers will appear here.",
                actionTitle: "Start"
            ) {}
        }
        .padding()
    }
    .screenBackground()
    .environment(AppRouter())
}
