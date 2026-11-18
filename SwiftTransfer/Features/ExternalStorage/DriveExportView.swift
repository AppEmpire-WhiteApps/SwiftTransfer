import SwiftData
import SwiftUI

/// "Save to an external drive": choose a folder on the drive, choose data, write and verify.
struct DriveExportView: View {
    @State private var model = DriveExportModel()
    @State private var showsFolderPicker = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    var body: some View {
        content
            .navigationTitle(Text("Save to drive"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(model.isWorking)
            .toolbar {
                if model.isWorking {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) {
                            model.cancel()
                        }
                    }
                }
            }
            .sheet(isPresented: $showsFolderPicker) {
                FolderPicker { url in
                    showsFolderPicker = false
                    model.folderPicked(url)
                } onCancel: {
                    showsFolderPicker = false
                }
                .ignoresSafeArea()
            }
            .alert(
                Text("Some files are larger than 4 GB"),
                isPresented: Binding(
                    get: { model.fat32Warning != nil },
                    set: { if !$0 { model.fat32Warning = nil } }
                ),
                presenting: model.fat32Warning
            ) { _ in
                Button("Skip these files") {
                    model.continueSkippingOversized()
                }
                Button("Cancel", role: .cancel) {
                    model.cancelAfterWarning()
                }
            } message: { warning in
                Text("The drive uses FAT32, which can't store files over 4 GB (\(warning.oversized.count) files). Format the drive as exFAT to keep them, or skip them.")
            }
            .onAppear {
                model.premiumAccess = router.premiumAccess
                model.onFinish = { record in
                    modelContext.insert(record)
                    try? modelContext.save()
                }
            }
            .onChange(of: model.isWorking) { _, working in
                UIApplication.shared.isIdleTimerDisabled = working
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .chooseFolder:
            chooseFolder
                .trackScreen("drive_export_folder")
        case .selectData:
            SelectDataView(selection: $model.selection, target: .storage) {
                model.start()
            }
            .safeAreaInset(edge: .top) {
                destinationBanner
            }
        case .preparing:
            progressView(
                fraction: model.preparationProgress,
                title: "Preparing data…",
                detail: Text("Reading contacts, calendars and the photo library.")
            )
            .trackScreen("drive_export_progress")
        case .writing:
            progressView(
                fraction: model.progress.fraction,
                title: model.progress.phase == .verifying ? "Verifying files…" : "Saving to the drive…",
                detail: writingDetail
            )
            .trackScreen("drive_export_progress")
        case .done:
            doneView
                .trackScreen("drive_export_done")
        case .failed(let message):
            failedView(message)
                .trackScreen("drive_export_failed")
        }
    }

    // MARK: Steps

    private var chooseFolder: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(illustration: .storageDrive, height: 200, glow: true, floating: true)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.s) {
                    Text("Connect the drive")
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Plug a USB-C flash drive or SSD into this iPhone, then choose a folder on it. Drives formatted as exFAT work best.")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: Spacing.m) {
                    tip("folder", "A dated transfer folder is created with Contacts, Calendar, Photos and other folders.")
                    tip("checkmark.seal", "Every file is checked after saving.")
                    tip("lock.shield", "Anyone with the drive can open these files. Keep it safe.")
                }
                .cardStyle()
                Button {
                    showsFolderPicker = true
                } label: {
                    Label("Choose folder on drive", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.primary)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .pageMargins()
        }
        .screenBackground()
    }

    private var destinationBanner: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(AppColor.primary)
            Text("Saving to “\(model.destinationName)”")
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
            Spacer()
            Button("Change") {
                showsFolderPicker = true
            }
            .font(AppFont.footnote.weight(.semibold))
            .foregroundStyle(AppColor.primary)
        }
        .padding(.vertical, Spacing.s)
        .pageMargins()
        .background(AppColor.skyMist)
    }

    private var writingDetail: Text {
        let progress = model.progress
        if progress.phase == .verifying {
            return Text("\(progress.completedFiles) of \(progress.totalFiles) files checked")
        }
        let done = Text(progress.completedBytes, format: .byteCount(style: .file))
        let total = Text(progress.totalBytes, format: .byteCount(style: .file))
        return Text("\(done) of \(total) · \(progress.completedFiles) of \(progress.totalFiles) files")
    }

    private func progressView(fraction: Double, title: LocalizedStringKey, detail: Text) -> some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                ProgressRing(progress: fraction)
                    .frame(width: 220, height: 220)
                    .padding(.top, Spacing.xxl)
                VStack(spacing: Spacing.s) {
                    Text(title)
                        .font(AppFont.title2)
                        .foregroundStyle(AppColor.textPrimary)
                    detail
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Label("Don't disconnect the drive and keep the app open.", systemImage: "exclamationmark.triangle")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .cardStyle(background: AppColor.skyMist)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .pageMargins()
        }
        .screenBackground()
    }

    private var doneView: some View {
        let result = model.result
        let issues = (result?.skipped.count ?? 0) + (result?.verificationFailures.count ?? 0)
        return ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(illustration: issues == 0 ? .success : .partialSuccess, height: 200, glow: true)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.s) {
                    Text(issues == 0 ? "Saved to the drive" : "Saved with some issues")
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Connect the drive to your Android phone and open its Files app.")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let result {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        StatusRow(
                            title: "Files saved",
                            detail: Text("\(result.manifest.entries.count) files in “\(result.packageURL.lastPathComponent)”"),
                            status: .ok
                        )
                        StatusRow(
                            title: "Verification",
                            detail: result.verified ? Text("All files match") : Text("\(result.verificationFailures.count) files differ"),
                            status: result.verified ? .ok : .warning
                        )
                        if !result.skipped.isEmpty {
                            StatusRow(
                                title: "Skipped",
                                detail: Text("\(result.skipped.count) files couldn't be saved"),
                                status: .warning
                            )
                        }
                    }
                    .cardStyle()
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("On the Android phone")
                            .font(AppFont.headline)
                        Text("Contacts: open contacts.vcf and choose Contacts. Calendar: import calendar.ics in Google Calendar on the web or open it in a calendar app. Photos and files: copy the folders to the phone storage.")
                            .font(AppFont.callout)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(background: AppColor.skyMist)
                }
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.primary)
                Button("Save more data") {
                    model.reset()
                }
                .buttonStyle(.text)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .pageMargins()
        }
        .screenBackground()
    }

    private func failedView(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(illustration: .errorConnection, height: 200)
                    .accessibilityHidden(true)
                VStack(spacing: Spacing.s) {
                    Text("Couldn't save to the drive")
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Try again") {
                    model.reset()
                }
                .buttonStyle(.primary)
                Button("Choose another folder") {
                    showsFolderPicker = true
                }
                .buttonStyle(.secondary)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
            .pageMargins()
        }
        .screenBackground()
    }

    private func tip(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AppColor.primary)
        }
    }
}

#Preview {
    NavigationStack {
        DriveExportView()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
    .modelContainer(for: TransferRecord.self, inMemory: true)
}
