import SwiftData
import SwiftUI

/// "Restore from a drive": choose a package (or any folder), review, import with progress, see the result.
struct DriveRestoreView: View {
    @State private var model = DriveRestoreModel()
    @State private var showsFolderPicker = false
    @AppStorage(SettingsKey.duplicatePolicy) private var storedPolicy = DuplicatePolicy.skip.rawValue
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                stepContent
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .pageMargins()
        }
        .screenBackground()
        .navigationTitle(Text("Restore from drive"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.step == .importing)
        .trackScreen(screenName)
        .sheet(isPresented: $showsFolderPicker) {
            FolderPicker { url in
                showsFolderPicker = false
                model.folderPicked(url)
            } onCancel: {
                showsFolderPicker = false
            }
            .ignoresSafeArea()
        }
        .onAppear {
            model.premiumAccess = router.premiumAccess
            model.policy = DuplicatePolicy(rawValue: storedPolicy) ?? .skip
            model.onFinish = { record in
                modelContext.insert(record)
                try? modelContext.save()
            }
        }
        .onChange(of: model.step) { _, step in
            UIApplication.shared.isIdleTimerDisabled = step == .importing
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var screenName: String {
        switch model.step {
        case .chooseFolder: "drive_restore_folder"
        case .review: "drive_restore_review"
        case .importing: "drive_restore_progress"
        case .done: "drive_restore_done"
        case .failed: "drive_restore_failed"
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .chooseFolder:
            chooseFolder
        case .review:
            review
        case .importing:
            importing
        case .done:
            done
        case .failed(let message):
            failed(message)
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var chooseFolder: some View {
        IllustrationView(illustration: .deviceStorage, height: 200, glow: true, floating: true)
            .accessibilityHidden(true)
        heading(
            "Restore from a drive",
            message: "Connect the drive and choose the transfer folder. Folders with photos or files from an Android phone work too."
        )
        Button {
            showsFolderPicker = true
        } label: {
            Label("Choose folder", systemImage: "folder")
        }
        .buttonStyle(.primary)
    }

    @ViewBuilder
    private var review: some View {
        IllustrationView(illustration: .deviceStorage, height: 150)
            .accessibilityHidden(true)
        heading("Ready to import", message: "“\(model.packageName)”")
        if model.isIncomplete {
            Label("This package was not saved completely. Files that are present can still be imported.", systemImage: "exclamationmark.triangle.fill")
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.warning)
                .fixedSize(horizontal: false, vertical: true)
                .cardStyle(background: AppColor.skyMist)
        }
        VStack(spacing: Spacing.m) {
            ForEach(model.fileCounts, id: \.0) { category, count in
                HStack(spacing: Spacing.m) {
                    category.illustration.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                    Text(category.title)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text("\(count) files")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            Divider()
            HStack {
                Text("Total")
                    .font(AppFont.headline)
                Spacer()
                Text(model.totalBytes, format: .byteCount(style: .file))
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .cardStyle()
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Duplicates")
                .font(AppFont.headline)
            Picker(selection: $model.policy) {
                ForEach(DuplicatePolicy.allCases, id: \.self) { policy in
                    Text(policy.title).tag(policy)
                }
            } label: {
                Text("Duplicates")
            }
            .pickerStyle(.segmented)
            Text("Nothing on this iPhone is changed or deleted. Imported items can be undone from History.")
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        Button("Import to this iPhone") {
            model.startImport()
        }
        .buttonStyle(.primary)
        Button("Choose another folder") {
            showsFolderPicker = true
        }
        .buttonStyle(.text)
    }

    @ViewBuilder
    private var importing: some View {
        ProgressRing(progress: model.progress)
            .frame(width: 220, height: 220)
            .padding(.top, Spacing.xl)
        heading("Importing…", message: "\(model.done) of \(model.total) files")
        Label("Keep the drive connected and the app open.", systemImage: "exclamationmark.triangle")
            .font(AppFont.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .cardStyle(background: AppColor.skyMist)
    }

    @ViewBuilder
    private var done: some View {
        let report = model.report ?? ImportReport()
        let failed = !report.failures.isEmpty
        IllustrationView(illustration: failed ? .partialSuccess : .success, height: 200, glow: true)
            .accessibilityHidden(true)
        heading(
            failed ? "Imported with some issues" : "Import complete",
            message: "Your data was added to this iPhone."
        )
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(DataCategory.allCases) { category in
                if let count = report.imported[category], count > 0 {
                    StatusRow(title: categoryKey(category), detail: Text("\(count) added"), status: .ok)
                }
                if let skipped = report.skippedDuplicates[category], skipped > 0 {
                    StatusRow(title: categoryKey(category), detail: Text("\(skipped) duplicates skipped"), status: .ok)
                }
            }
            if report.savedFiles > 0 {
                StatusRow(title: "Files", detail: Text("Saved in the app's Received folder in Files → On My iPhone"), status: .ok)
            }
            ForEach(report.failures.prefix(20), id: \.self) { failure in
                StatusRow(title: LocalizedStringKey(failure.path), detail: Text(failure.reason), status: .failed)
            }
            if report.failures.count > 20 {
                Text("and \(report.failures.count - 20) more")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .cardStyle()
        Button("Done") {
            dismiss()
        }
        .buttonStyle(.primary)
    }

    @ViewBuilder
    private func failed(_ message: String) -> some View {
        IllustrationView(illustration: .errorConnection, height: 200)
            .accessibilityHidden(true)
        heading("Couldn't open the folder", message: LocalizedStringKey(message))
        Button("Choose another folder") {
            showsFolderPicker = true
        }
        .buttonStyle(.primary)
    }

    private func categoryKey(_ category: DataCategory) -> LocalizedStringKey {
        LocalizedStringKey(String(localized: category.title))
    }

    private func heading(_ title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.s) {
            Text(title)
                .font(AppFont.title1)
                .foregroundStyle(AppColor.textPrimary)
            Text(message)
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    NavigationStack {
        DriveRestoreView()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
    .modelContainer(for: TransferRecord.self, inMemory: true)
}
