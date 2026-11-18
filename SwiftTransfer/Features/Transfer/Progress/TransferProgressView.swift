import SwiftUI

/// S6: transfer progress by bytes actually sent/received (TZ §4.9).
struct TransferProgressView: View {
    let model: TransferFlowModel

    @AppStorage(SettingsKey.keepScreenAwake) private var keepScreenAwake = true
    @State private var showsCancelConfirmation = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var progress: TransferProgressState {
        model.progress
    }

    private var isWeb: Bool {
        model.webMode != nil && model.method != .peer
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: Spacing.xl) {
                        VStack(spacing: Spacing.xl) {
                            hero
                            metrics
                        }
                        VStack(spacing: Spacing.l) {
                            categoryList
                            banner
                        }
                    }
                } else {
                    hero
                    metrics
                    banner
                    categoryList
                }
                controls
            }
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
            .padding(.bottom, 72)
        }
        .navigationTitle(Text("Transfer"))
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
            TransferNotifications.prepare()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sensoryFeedback(.impact(weight: .light), trigger: progress.completedCategoryCount)
        .sensoryFeedback(.warning, trigger: progress.isReconnecting) { _, new in new }
        .confirmationDialog("Cancel the transfer?", isPresented: $showsCancelConfirmation, titleVisibility: .visible) {
            Button("Cancel transfer", role: .destructive) {
                model.cancelTransfer()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Items that already arrived stay on the receiving device.")
        }
        .trackScreen("transfer_progress")
    }

    private var title: LocalizedStringKey {
        if progress.isImporting {
            return model.role == .send ? "Saving on the other device…" : "Saving to this device…"
        }
        if progress.isReconnecting {
            return "Reconnecting…"
        }
        if progress.isPaused {
            return "Paused"
        }
        if model.webMode == .upload, progress.bytesTotal == 0 {
            return "Choose files on the Android phone"
        }
        if model.webMode == .download, progress.allDelivered {
            return "Everything is downloaded"
        }
        return model.role == .send ? "Sending…" : "Receiving…"
    }

    private var hero: some View {
        VStack(spacing: Spacing.l) {
            Text(title)
                .font(AppFont.title1)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            ZStack {
                ProgressRing(progress: progress.fraction, lineWidth: 18)
                    .frame(width: 220, height: 220)
                    .accessibilityLabel(Text("Progress"))
                    .accessibilityValue(Text("\(Int((progress.fraction * 100).rounded())) percent"))
            }
            TransferParticlesView(
                isAnimating: !progress.isPaused && !progress.isReconnecting && model.phase == .transferring,
                height: 140
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var metrics: some View {
        VStack(spacing: Spacing.m) {
            if progress.isImporting {
                if progress.importTotal > 0 {
                    Text("\(progress.importDone) of \(progress.importTotal) items saved")
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                } else {
                    ProgressView()
                }
            } else {
                Text("\(progress.bytesDone.byteString) of \(progress.bytesTotal.byteString)")
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
                HStack(spacing: Spacing.xl) {
                    metric(
                        title: "Speed",
                        value: progress.bytesPerSecond.map { "\(Int64($0).byteString)/s" } ?? "—"
                    )
                    metric(
                        title: "Time left",
                        value: progress.remaining?.remainingString ?? "—"
                    )
                }
                if model.webMode == .upload, progress.receivedFiles > 0 {
                    Text("\(progress.receivedFiles) files received")
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func metric(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
            Text(value)
                .font(AppFont.callout.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var banner: some View {
        Label {
            Text("Don't lock the screen and keep devices close")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.open.display")
        }
        .font(AppFont.callout)
        .foregroundStyle(AppColor.primaryDeep)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .background(AppColor.skyLight, in: RoundedRectangle(cornerRadius: Radius.small))
    }

    @ViewBuilder
    private var categoryList: some View {
        if !progress.categories.isEmpty {
            VStack(spacing: 0) {
                ForEach(progress.categories) { item in
                    CategoryProgressRow(item: item)
                    if item.id != progress.categories.last?.id {
                        Divider().overlay(AppColor.divider)
                    }
                }
            }
            .cardStyle(padding: Spacing.m)
        }
    }

    private var controls: some View {
        VStack(spacing: Spacing.m) {
            if isWeb {
                Button(model.webMode == .upload ? "Finish and save" : "Finish") {
                    model.finishWebSession()
                }
                .buttonStyle(.primary)
                .disabled(model.phase == .importing)
                if model.webMode == .download {
                    Text("Keep this screen open until the Android phone finishes downloading.")
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if model.canPause {
                Button(progress.isPaused ? "Resume" : "Pause") {
                    model.setPaused(!progress.isPaused)
                }
                .buttonStyle(.secondary)
            }
            if model.phase != .importing {
                Button("Cancel", role: .destructive) {
                    showsCancelConfirmation = true
                }
                .buttonStyle(.text)
            }
        }
        .frame(maxWidth: 480)
    }
}

/// One category with its own progress and status.
private struct CategoryProgressRow: View {
    let item: CategoryProgress

    private var fraction: Double {
        if item.bytesTotal > 0 {
            return min(1, Double(item.bytesDone) / Double(item.bytesTotal))
        }
        return item.itemsTotal > 0 ? Double(item.itemsDone) / Double(item.itemsTotal) : 0
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            item.category.illustration.image
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(item.category.title)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer(minLength: Spacing.s)
                    Text("\(item.itemsDone)/\(item.itemsTotal)")
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .monospacedDigit()
                }
                ProgressView(value: fraction)
                    .tint(item.failures > 0 ? AppColor.warning : AppColor.primary)
                statusText
                    .font(AppFont.caption)
            }
            statusIcon
                .frame(width: 24)
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusText: some View {
        switch item.status {
        case .pending:
            Text("Waiting").foregroundStyle(AppColor.textTertiary)
        case .running:
            Text("In progress").foregroundStyle(AppColor.primary)
        case .ok:
            Text("Done").foregroundStyle(AppColor.success)
        case .warning, .failed:
            Text("Errors (\(item.failures))").foregroundStyle(AppColor.warning)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Image(systemName: "clock").foregroundStyle(AppColor.textTertiary)
        case .running:
            ProgressView().controlSize(.small)
        case .ok:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColor.success)
        case .warning, .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(AppColor.warning)
        }
    }
}

#Preview {
    NavigationStack {
        TransferProgressView(model: TransferFlowModel(start: .send(.iPhone)))
            .screenBackground()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}
