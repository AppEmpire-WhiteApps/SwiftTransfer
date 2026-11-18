import SwiftUI

/// S7: transfer summary, errors, guide link and assistant.
struct TransferResultView: View {
    let model: TransferFlowModel
    let onOpenGuide: (GuideID) -> Void
    let onAskAssistant: () -> Void
    let onDone: () -> Void

    @State private var showsAllErrors = false

    private var outcome: TransferOutcome? {
        model.outcome
    }

    private var isSuccess: Bool {
        outcome?.status == .completed
    }

    private var guide: GuideID {
        let role = outcome?.role ?? model.role
        return role == .send ? .importSamsung : .androidIphone
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(illustration: isSuccess ? .success : .partialSuccess, height: 200, floating: true)
                VStack(spacing: Spacing.s) {
                    Text(title)
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    if let outcome {
                        Text(summary(outcome))
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let outcome {
                    countsCard(outcome)
                    if !outcome.failures.isEmpty {
                        errorsCard(outcome)
                    }
                }
                actions
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .navigationTitle(Text("Result"))
        .sensoryFeedback(trigger: outcome?.status) { _, status in
            switch status {
            case .completed: .success
            case .partial: .warning
            case .failed: .error
            case .cancelled, nil: nil
            }
        }
        .trackScreen("transfer_result")
    }

    private var title: LocalizedStringKey {
        switch outcome?.status {
        case .completed: "Transfer complete"
        case .partial: "Transfer finished with errors"
        case .failed: "Transfer failed"
        case .cancelled: "Transfer cancelled"
        case nil: "Transfer"
        }
    }

    private func summary(_ outcome: TransferOutcome) -> String {
        let parts = DataCategory.allCases.compactMap { category -> String? in
            guard let count = outcome.counts[category], count > 0 else { return nil }
            return "\(count) \(String(localized: category.title).lowercased())"
        }
        let moved = parts.isEmpty ? String(localized: "nothing") : parts.joined(separator: ", ")
        let verb = outcome.role == .send ? String(localized: "Transferred") : String(localized: "Received")
        return "\(verb): \(moved) · \(outcome.bytes.byteString)"
    }

    private func countsCard(_ outcome: TransferOutcome) -> some View {
        VStack(spacing: Spacing.s) {
            ForEach(DataCategory.allCases.filter { (outcome.counts[$0] ?? 0) > 0 || (outcome.skippedDuplicates[$0] ?? 0) > 0 }, id: \.self) { category in
                HStack(spacing: Spacing.m) {
                    category.illustration.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                    Text(category.title)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer(minLength: Spacing.s)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(outcome.counts[category] ?? 0)")
                            .font(AppFont.headline)
                            .foregroundStyle(AppColor.textPrimary)
                        if let skipped = outcome.skippedDuplicates[category], skipped > 0 {
                            Text("\(skipped) duplicates skipped")
                                .font(AppFont.caption)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if outcome.savedFiles > 0 {
                Label("\(outcome.savedFiles) files saved to the app folder in Files → On My iPhone", systemImage: "folder")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Label(outcome.duration.formattedDuration, systemImage: "clock")
                Spacer()
                if !outcome.peerName.isEmpty {
                    Label(outcome.peerName, systemImage: outcome.method == .peer ? "iphone" : "smartphone")
                        .lineLimit(1)
                }
            }
            .font(AppFont.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.top, Spacing.xs)
        }
        .cardStyle()
    }

    private func errorsCard(_ outcome: TransferOutcome) -> some View {
        let visible = showsAllErrors ? outcome.failures : Array(outcome.failures.prefix(5))
        return VStack(alignment: .leading, spacing: Spacing.s) {
            Label("\(outcome.failures.count) items not transferred", systemImage: "exclamationmark.triangle.fill")
                .font(AppFont.headline)
                .foregroundStyle(AppColor.warning)
            ForEach(Array(visible.enumerated()), id: \.offset) { _, failure in
                VStack(alignment: .leading, spacing: 2) {
                    Text((failure.path as NSString).lastPathComponent)
                        .font(AppFont.callout.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                    Text(failure.reason)
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if outcome.failures.count > 5 {
                Button(showsAllErrors ? "Show less" : "Show all") {
                    showsAllErrors.toggle()
                }
                .buttonStyle(.text)
            }
            if model.canRetryFailed {
                Button("Retry failed") {
                    model.retryFailed()
                }
                .buttonStyle(.secondary)
                .disabled(model.isRetrying)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            Button("Done", action: onDone)
                .buttonStyle(.primary)
            if outcome?.status != .cancelled {
                Button("How to find data on the new phone") {
                    onOpenGuide(guide)
                }
                .buttonStyle(.secondary)
            }
            if outcome?.failures.isEmpty == false || outcome?.status == .failed {
                Button {
                    onAskAssistant()
                } label: {
                    Label("Ask the assistant", systemImage: "sparkles")
                }
                .buttonStyle(.text)
            }
        }
    }
}

extension TimeInterval {
    /// "4 min 12 s"
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .short
        return formatter.string(from: max(1, self)) ?? ""
    }
}

#Preview {
    NavigationStack {
        TransferResultView(model: TransferFlowModel(start: .send(.iPhone)), onOpenGuide: { _ in }, onAskAssistant: {}, onDone: {})
            .screenBackground()
    }
    .environment(AppActivityContext())
}
