import SwiftUI

/// S10.1: horizontal pager of guide steps with a progress indicator and Back/Next buttons.
struct GuideDetailView: View {
    let guide: GuideID

    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    private var content: Guide {
        GuideLibrary.guide(guide)
    }

    var body: some View {
        Group {
            if content.steps.isEmpty {
                faqBody
            } else {
                pagerBody
            }
        }
        .screenBackground()
        .navigationTitle(Text(content.title))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("guide_\(guide.rawValue)")
        .premiumLocked(!router.premiumAccess.isPremium) {
            _ = router.premiumAccess.authorize(.guides)
        }
        .task {
            _ = router.premiumAccess.authorize(.guides)
        }
    }

    // MARK: - Pager

    private var pagerBody: some View {
        VStack(spacing: 0) {
            progressHeader
                .pageMargins()
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.m)

            TabView(selection: $index) {
                ForEach(Array(content.steps.enumerated()), id: \.element.id) { offset, step in
                    GuideStepPage(step: step, onAction: perform)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomBar
                .frame(maxWidth: 700)
                .pageMargins()
                .padding(.vertical, Spacing.m)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: Spacing.m) {
            if content.showsPhases, let phase = content.steps[safeIndex].phase {
                StepIndicator(current: phase)
                    .frame(maxWidth: 520)
            }
            HStack(spacing: Spacing.xs) {
                ForEach(content.steps.indices, id: \.self) { position in
                    Capsule()
                        .fill(position <= safeIndex ? AnyShapeStyle(AppGradient.primary) : AnyShapeStyle(AppColor.skyLight))
                        .frame(height: 4)
                }
            }
            .frame(maxWidth: 520)
            .accessibilityHidden(true)
            Text("Step \(safeIndex + 1) of \(content.steps.count)")
                .font(AppFont.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: index)
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                if safeIndex > 0 {
                    Button {
                        go(to: safeIndex - 1)
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.secondary)
                }
                if isLastStep {
                    if let start = content.transferStart {
                        Button {
                            router.startTransfer(start)
                        } label: {
                            Label("Start transfer", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.primary)
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.primary)
                    }
                } else {
                    Button {
                        go(to: safeIndex + 1)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(GuideTrailingIconLabelStyle())
                    }
                    .buttonStyle(.primary)
                }
            }
            askAssistantButton
        }
    }

    // MARK: - FAQ

    private var faqBody: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(illustration: content.cover, height: 170, floating: true)
                Text(content.summary)
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                GuideFAQList(items: content.faq)
                askAssistantButton
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
    }

    private var askAssistantButton: some View {
        Button {
            let title = String(localized: content.title)
            router.askAssistant(draft: String(localized: "I have a question about the guide “\(title)”: "))
        } label: {
            Label("Ask the assistant about this guide", systemImage: "sparkles")
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.text)
    }

    // MARK: - Helpers

    private var safeIndex: Int {
        min(max(index, 0), max(content.steps.count - 1, 0))
    }

    private var isLastStep: Bool {
        safeIndex == content.steps.count - 1
    }

    private func go(to newIndex: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            index = newIndex
        }
    }

    private func perform(_ kind: GuideStepAction.Kind) {
        switch kind {
        case .route:
            // Routes are rendered as NavigationLinks by the page.
            break
        case .transfer(let start):
            router.startTransfer(start)
        case .assistant(let action):
            router.perform(action)
        }
    }
}

/// One page of the guide pager.
private struct GuideStepPage: View {
    let step: GuideStep
    let onAction: (GuideStepAction.Kind) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(
                    illustration: step.illustration,
                    height: sizeClass == .regular ? 280 : 210
                )
                .padding(.top, Spacing.s)
                VStack(spacing: Spacing.m) {
                    Text(step.title)
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(step.text)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                if let action = step.action {
                    actionButton(action)
                }
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.bottom, Spacing.l)
        }
    }

    @ViewBuilder
    private func actionButton(_ action: GuideStepAction) -> some View {
        let label = Label {
            Text(action.title)
        } icon: {
            Image(systemName: action.systemImage)
        }
        .font(AppFont.callout.weight(.semibold))
        .foregroundStyle(AppColor.primaryDeep)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .frame(minHeight: 44)
        .background(AppColor.skyLight, in: Capsule())

        switch Self.route(for: action.kind) {
        case .some(let route):
            NavigationLink(value: route) {
                label
            }
            .buttonStyle(.plain)
        case .none:
            Button {
                onAction(action.kind)
            } label: {
                label
            }
            .buttonStyle(.plain)
        }
    }

    /// Actions that open a screen are pushed onto the current stack instead of switching tabs.
    static func route(for kind: GuideStepAction.Kind) -> AppRoute? {
        switch kind {
        case .route(let route):
            return route
        case .assistant(let action):
            if let guide = action.guide {
                return .guide(guide)
            }
            switch action {
            case .openConnectionCheck:
                return .connectionCheck
            case .openStorageExport:
                return .externalStorage
            default:
                return nil
            }
        case .transfer:
            return nil
        }
    }
}

/// Title first, icon after it (for "Next").
private struct GuideTrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.s) {
            configuration.title
            configuration.icon
        }
    }
}

#Preview("Wi-Fi guide") {
    NavigationStack {
        GuideDetailView(guide: .wifiGalaxy)
            .appRouteDestinations()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}

#Preview("FAQ") {
    NavigationStack {
        GuideDetailView(guide: .faq)
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}
