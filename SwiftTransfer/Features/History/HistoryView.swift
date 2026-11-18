import SwiftData
import SwiftUI

/// S13: list of past transfers, newest first.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query(sort: \TransferRecord.date, order: .reverse) private var records: [TransferRecord]

    var body: some View {
        Group {
            if records.isEmpty {
                ScrollView {
                    EmptyStateView(
                        illustration: .emptyHistory,
                        title: "No transfers yet",
                        message: "Your transfers will appear here, so you can repeat them or undo an import.",
                        actionTitle: "Start a transfer"
                    ) {
                        router.startTransfer(.send(nil))
                    }
                    .padding(.top, Spacing.xxl)
                    .pageMargins()
                }
            } else {
                List {
                    ForEach(records) { record in
                        NavigationLink {
                            HistoryDetailView(record: record)
                        } label: {
                            HistoryRow(record: record)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: Radius.card - 6, style: .continuous)
                                .fill(AppColor.surface)
                                .padding(.vertical, Spacing.xs)
                        )
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .screenBackground()
        .navigationTitle("History")
        .toolbar {
            if !records.isEmpty {
                EditButton()
            }
        }
        .trackScreen("history")
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}

/// One transfer in the list.
private struct HistoryRow: View {
    let record: TransferRecord

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: record.role.historySystemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColor.primary)
                .frame(width: 40, height: 40)
                .background(AppColor.skyMist, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.method.title)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text("\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(record.totalBytes.formatted(.byteCount(style: .file)))")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HistoryStatusBadge(status: record.status)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

/// Colored capsule with the transfer status.
struct HistoryStatusBadge: View {
    let status: TransferStatus

    var body: some View {
        Text(status.historyTitle)
            .font(AppFont.caption.weight(.semibold))
            .foregroundStyle(status.historyColor)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 3)
            .background(status.historyColor.opacity(0.12), in: Capsule())
    }
}

#Preview("History") {
    let container = HistoryPreviewData.container()
    return NavigationStack {
        HistoryView()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
    .modelContainer(container)
}

#Preview("Empty") {
    NavigationStack {
        HistoryView()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
    .modelContainer(for: [TransferRecord.self, ChatThread.self, ChatMessage.self], inMemory: true)
}

/// Sample records for previews.
@MainActor
enum HistoryPreviewData {
    static func container() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(
            for: TransferRecord.self, ChatThread.self, ChatMessage.self,
            configurations: configuration
        ) else {
            fatalError("Preview container")
        }
        for record in records() {
            container.mainContext.insert(record)
        }
        return container
    }

    static func records() -> [TransferRecord] {
        [
            TransferRecord(
                date: .now.addingTimeInterval(-3600),
                role: .receive,
                method: .peer,
                peerName: "iPhone",
                categoryCounts: [.contacts: 312, .photos: 1245, .calendar: 48],
                totalBytes: 3_400_000_000,
                duration: 512,
                status: .partial,
                errorSummaries: ["3 photos couldn't be saved"],
                created: CreatedIdentifiers(contacts: ["a", "b"], assets: ["c"])
            ),
            TransferRecord(
                date: .now.addingTimeInterval(-86_400 * 3),
                role: .send,
                method: .webAndroid,
                peerName: "Android",
                categoryCounts: [.contacts: 312, .videos: 20],
                totalBytes: 1_200_000_000,
                duration: 140,
                status: .completed
            ),
        ]
    }
}
