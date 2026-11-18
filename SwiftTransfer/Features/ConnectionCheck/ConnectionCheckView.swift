import SwiftUI
import UIKit

/// S9: sequential connection checks with a graded result, time estimate and personal tips.
struct ConnectionCheckView: View {
    /// Size for the time estimate; nil uses the current transfer size or 5 GB.
    var transferBytes: Int64?

    @Environment(AppRouter.self) private var router
    @Environment(AppActivityContext.self) private var activity
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var model = ConnectionCheckModel()
    @State private var runID = 0
    @State private var didConfigure = false

    init(transferBytes: Int64? = nil) {
        self.transferBytes = transferBytes
    }

    var body: some View {
        ScrollView {
            Group {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: Spacing.xxl) {
                        VStack(spacing: Spacing.xl) {
                            header
                            checksCard
                        }
                        .frame(maxWidth: .infinity)
                        VStack(spacing: Spacing.xl) {
                            resultSection
                            actions
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: 1040)
                } else {
                    VStack(spacing: Spacing.xl) {
                        header
                        checksCard
                        resultSection
                        actions
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .screenBackground()
        .navigationTitle("Connection check")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: runID) {
            configureIfNeeded()
            model.animatesChanges = !reduceMotion
            await model.run(peer: PeerLinkRegistry.shared.current)
            if let info = model.contextInfo {
                activity.connectionCheck = info
            }
        }
        .trackScreen("connection_check")
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Spacing.m) {
            IllustrationView(
                illustration: .connectionCheck,
                height: sizeClass == .regular ? 200 : 160,
                floating: model.isRunning
            )
            Text("Let's check your connection")
                .font(AppFont.title1)
                .foregroundStyle(AppColor.textPrimary)
            Text("Wi-Fi, permissions, power settings, battery and free space. It takes up to 15 seconds.")
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
    }

    private var checksCard: some View {
        VStack(spacing: 0) {
            ForEach(ConnectionCheckItem.allCases) { item in
                StatusRow(
                    title: item.title,
                    detail: model.details[item].map { Text($0) },
                    status: model.status(of: item)
                )
                if item != ConnectionCheckItem.allCases.last {
                    Divider()
                        .overlay(AppColor.divider)
                        .padding(.leading, 40)
                }
            }
            if model.localNetworkDenied {
                Button {
                    openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.secondary)
                .padding(.top, Spacing.m)
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var resultSection: some View {
        if let assessment = model.assessment {
            ConnectionResultCard(
                assessment: assessment,
                sizeOptions: sizeOptions,
                selectedBytes: Binding(
                    get: { model.transferBytes },
                    set: { model.transferBytes = $0 }
                ),
                onOpenSettings: openSettings
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if sizeClass == .regular {
            VStack(spacing: Spacing.m) {
                ProgressView()
                    .tint(AppColor.primary)
                Text("The result appears when all checks are done.")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .cardStyle(padding: Spacing.xxl, background: AppColor.skyMist)
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            Button {
                runID += 1
            } label: {
                Label("Run again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.primary(isLoading: model.isRunning))
            .disabled(model.isRunning)

            Button {
                discussWithAssistant()
            } label: {
                Label("Discuss with the assistant", systemImage: "sparkles")
            }
            .buttonStyle(.secondary)
            .disabled(model.isRunning)
        }
    }

    // MARK: - Helpers

    private var sizeOptions: [Int64] {
        var options: [Int64] = [1_000_000_000, 5_000_000_000, 20_000_000_000, 64_000_000_000]
        if let custom = initialBytes, !options.contains(custom) {
            options.insert(custom, at: 0)
        }
        return options
    }

    private var initialBytes: Int64? {
        if let transferBytes, transferBytes > 0 {
            return transferBytes
        }
        if let current = activity.transfer?.totalBytes, current > 0 {
            return current
        }
        return nil
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        if let initialBytes {
            model.transferBytes = initialBytes
        }
    }

    private func discussWithAssistant() {
        if let info = model.contextInfo {
            activity.connectionCheck = info
        }
        router.askAssistant(draft: model.assistantDraft())
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

// MARK: - Result card

private struct ConnectionResultCard: View {
    let assessment: ConnectionAssessment
    let sizeOptions: [Int64]
    @Binding var selectedBytes: Int64
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            gradeHeader
            Divider()
                .overlay(AppColor.divider)
            estimate
            if !assessment.recommendations.isEmpty {
                Divider()
                    .overlay(AppColor.divider)
                recommendations
            }
        }
        .cardStyle(padding: Spacing.xl)
    }

    private var gradeColor: Color {
        switch assessment.grade {
        case .excellent: AppColor.success
        case .good: AppColor.primary
        case .weak: AppColor.warning
        }
    }

    private var gradeHeader: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Label {
                    Text(assessment.grade.title)
                } icon: {
                    Image(systemName: assessment.grade.systemImage)
                        .foregroundStyle(gradeColor)
                }
                .font(AppFont.title2)
                .foregroundStyle(AppColor.textPrimary)
                Text(assessment.grade.message)
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Illustration.connectionCheck.image
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 72)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var estimate: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Estimated transfer time")
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(sizeOptions, id: \.self) { bytes in
                        Button {
                            selectedBytes = bytes
                        } label: {
                            Chip(
                                title: Text(bytes.formatted(.byteCount(style: .file))),
                                isSelected: bytes == selectedBytes
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(bytes == selectedBytes ? .isSelected : [])
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Image(systemName: "clock")
                    .foregroundStyle(AppColor.primary)
                Text(Self.durationText(assessment.estimatedDuration(forBytes: selectedBytes)))
                    .font(AppFont.title2)
                    .foregroundStyle(AppColor.textPrimary)
                    .contentTransition(.numericText())
            }
            Text(speedText)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var speedText: LocalizedStringResource {
        let speed = Int64(assessment.throughputBytesPerSecond).formatted(.byteCount(style: .file))
        if assessment.isMeasured {
            return "Based on the measured speed of \(speed)/s."
        }
        return "Based on a typical Wi-Fi speed of \(speed)/s. Connect a second device to measure the real speed."
    }

    private var recommendations: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Recommendations")
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
            ForEach(assessment.recommendations) { tip in
                HStack(alignment: .top, spacing: Spacing.m) {
                    Image(systemName: tip.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColor.primary)
                        .frame(width: 36, height: 36)
                        .background(AppColor.skyMist, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tip.title)
                            .font(AppFont.callout.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text(tip.message)
                            .font(AppFont.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if tip == .allowLocalNetwork {
                            Button("Open Settings", action: onOpenSettings)
                                .buttonStyle(.text)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(localized: "Less than a minute")
        }
        let rounded = (seconds / 60).rounded(.up) * 60
        let formatted = Duration.seconds(rounded).formatted(.units(allowed: [.hours, .minutes], width: .wide))
        return String(localized: "About \(formatted)")
    }
}

#Preview("Connection check") {
    NavigationStack {
        ConnectionCheckView()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}

#Preview("Result card") {
    ScrollView {
        ConnectionResultCard(
            assessment: ConnectionAssessment(
                snapshot: DiagnosticsSnapshot(lowPowerMode: true, vpnActive: true, batteryLevel: 0.2),
                transferBytes: 20_000_000_000
            ),
            sizeOptions: [5_000_000_000, 20_000_000_000, 64_000_000_000],
            selectedBytes: .constant(20_000_000_000),
            onOpenSettings: {}
        )
        .padding()
    }
    .screenBackground()
}
