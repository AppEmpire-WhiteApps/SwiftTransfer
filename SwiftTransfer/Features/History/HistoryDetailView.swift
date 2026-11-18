import SwiftData
import SwiftUI

/// Details of one transfer: counts per category, duration, errors, repeat and undo import.
struct HistoryDetailView: View {
    let record: TransferRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var confirmsUndo = false
    @State private var isUndoing = false
    @State private var notice: SettingsNotice?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                header
                statsCard
                if !record.counts.isEmpty {
                    categoriesCard
                }
                if !record.errorSummaries.isEmpty {
                    errorsCard
                }
                actions
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .screenBackground()
        .navigationTitle("Transfer details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Undo this import?",
            isPresented: $confirmsUndo,
            titleVisibility: .visible
        ) {
            Button("Delete imported items", role: .destructive) {
                undoImport()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the \(record.created.historyTotalCount) items added by this transfer will be deleted from this device. Everything else stays.")
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .trackScreen("history_detail")
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Spacing.m) {
            IllustrationView(illustration: record.status.historyIllustration, height: 150)
            Text(record.method.title)
                .font(AppFont.title1)
                .foregroundStyle(AppColor.textPrimary)
            HistoryStatusBadge(status: record.status)
            Text(directionText)
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(record.date.formatted(date: .long, time: .shortened))
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textTertiary)
        }
        .multilineTextAlignment(.center)
    }

    private var directionText: LocalizedStringResource {
        let name = record.peerName
        switch record.role {
        case .send:
            return name.isEmpty ? "Sent" : "Sent to \(name)"
        case .receive:
            return name.isEmpty ? "Received" : "Received from \(name)"
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat(title: "Size", value: Text(record.totalBytes.formatted(.byteCount(style: .file))))
            Divider()
                .overlay(AppColor.divider)
            stat(title: "Duration", value: Text(Self.durationText(record.duration)))
            Divider()
                .overlay(AppColor.divider)
            stat(title: "Items", value: Text(record.historyTotalItems.formatted()))
        }
        .fixedSize(horizontal: false, vertical: true)
        .cardStyle()
    }

    private func stat(title: LocalizedStringKey, value: Text) -> some View {
        VStack(spacing: Spacing.xs) {
            value
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("What was transferred")
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
            ForEach(DataCategory.allCases) { category in
                if let count = record.counts[category] {
                    HStack(spacing: Spacing.m) {
                        category.illustration.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .accessibilityHidden(true)
                        Text(category.title)
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textPrimary)
                        Spacer(minLength: Spacing.s)
                        Text(count.formatted())
                            .font(AppFont.body.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                    }
                    .padding(.vertical, Spacing.xs)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardStyle()
    }

    private var errorsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Label("Problems", systemImage: "exclamationmark.triangle.fill")
                .font(AppFont.headline)
                .foregroundStyle(AppColor.warning)
            ForEach(Array(record.errorSummaries.enumerated()), id: \.offset) { _, summary in
                Text(verbatim: "• \(summary)")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardStyle()
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            if let start = record.historyRepeatStart {
                Button {
                    router.startTransfer(start)
                } label: {
                    Label("Repeat transfer", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.primary)
            }

            if record.historyCanUndoImport() {
                Button(role: .destructive) {
                    confirmsUndo = true
                } label: {
                    Label("Undo import", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.secondary)
                .disabled(isUndoing)
                Text("Available for 24 hours after the transfer.")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            } else if record.importUndone {
                Label("Import undone", systemImage: "checkmark.circle")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private func undoImport() {
        let created = record.created
        isUndoing = true
        Task {
            defer { isUndoing = false }
            do {
                try await ImportService().undoImport(created)
                record.importUndone = true
                try? modelContext.save()
                notice = SettingsNotice(
                    title: String(localized: "Import undone"),
                    message: String(localized: "The items added by this transfer were deleted.")
                )
            } catch {
                notice = SettingsNotice(
                    title: String(localized: "Couldn't undo the import"),
                    message: error.localizedDescription
                )
            }
        }
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let value = Duration.seconds(max(seconds, 0).rounded())
        if seconds < 60 {
            return value.formatted(.units(allowed: [.seconds], width: .abbreviated))
        }
        return value.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

#Preview {
    let container = HistoryPreviewData.container()
    let record = (try? container.mainContext.fetch(FetchDescriptor<TransferRecord>()))?.first
    return NavigationStack {
        if let record {
            HistoryDetailView(record: record)
        }
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
    .modelContainer(container)
}
