import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// S12: app settings in card-styled groups.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var sizeClass

    @AppStorage(SettingsKey.defaultMediaQuality) private var mediaQuality: MediaQuality = .original
    @AppStorage(SettingsKey.duplicatePolicy) private var duplicatePolicy: DuplicatePolicy = .skip
    @AppStorage(SettingsKey.keepScreenAwake) private var keepScreenAwake = true
    @AppStorage(SettingsKey.batteryReminder) private var batteryReminder = true
    @AppStorage(SettingsKey.assistantSendsContext) private var assistantSendsContext = true
    @AppStorage(SettingsKey.onboardingCompleted) private var onboardingCompleted = true

    @State private var importer = SettingsFileImportModel()
    @State private var showsFileImporter = false
    @State private var confirmsClearChats = false
    @State private var notice: SettingsNotice?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                SettingsPremiumBanner()
                generalSection
                transferSection
                assistantSection
                dataSection
                SettingsAppActions()
                SettingsAboutCard()
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .screenBackground()
        .navigationTitle("Settings")
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: SettingsFileImportModel.allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .confirmationDialog(
            "Delete all assistant chats?",
            isPresented: $confirmsClearChats,
            titleVisibility: .visible
        ) {
            Button("Delete all chats", role: .destructive) {
                clearChatHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .trackScreen("settings")
    }

    // MARK: - Sections

    private var generalSection: some View {
        SettingsSection(title: "General") {
            Button {
                openSystemSettings()
            } label: {
                SettingsRowLabel(
                    title: "App language",
                    systemImage: "globe",
                    subtitle: Text("Change the language in iOS Settings")
                )
            }
            .buttonStyle(.plain)
            SettingsDivider()
            Button {
                withAnimation(.easeInOut) {
                    onboardingCompleted = false
                }
            } label: {
                SettingsRowLabel(title: "Show onboarding again", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(.plain)
        }
    }

    private var transferSection: some View {
        SettingsSection(title: "Transfer", footer: "Applies to new transfers. You can change them for each transfer.") {
            Menu {
                Picker(selection: $mediaQuality) {
                    ForEach(MediaQuality.allCases, id: \.self) { quality in
                        Text(quality.title).tag(quality)
                    }
                } label: {
                    Text("Photo and video quality")
                }
            } label: {
                SettingsRowLabel(
                    title: "Photo and video quality",
                    systemImage: "photo",
                    subtitle: Text(mediaQuality.title)
                ) {
                    SettingsChevron(systemImage: "chevron.up.chevron.down")
                }
            }
            .buttonStyle(.plain)
            SettingsDivider()
            Menu {
                Picker(selection: $duplicatePolicy) {
                    ForEach(DuplicatePolicy.allCases, id: \.self) { policy in
                        Text(policy.title).tag(policy)
                    }
                } label: {
                    Text("Duplicates")
                }
            } label: {
                SettingsRowLabel(
                    title: "Duplicates",
                    systemImage: "square.on.square",
                    subtitle: Text(duplicatePolicy.title)
                ) {
                    SettingsChevron(systemImage: "chevron.up.chevron.down")
                }
            }
            .buttonStyle(.plain)
            SettingsDivider()
            Toggle(isOn: $keepScreenAwake) {
                SettingsRowLabel(
                    title: "Keep screen awake",
                    systemImage: "sun.max",
                    subtitle: Text("The screen doesn't turn off during a transfer")
                ) {
                    EmptyView()
                }
            }
            .tint(AppColor.primary)
            SettingsDivider()
            Toggle(isOn: $batteryReminder) {
                SettingsRowLabel(
                    title: "Battery reminder",
                    systemImage: "battery.50",
                    subtitle: Text("Suggest connecting a charger when the battery is low")
                ) {
                    EmptyView()
                }
            }
            .tint(AppColor.primary)
        }
    }

    private var assistantSection: some View {
        SettingsSection(
            title: "Assistant",
            footer: "When on, the assistant gets technical details with your question: app and iOS version, device model, interface language, current screen, transfer method, item counts and size, the last error, connection check results and permission states. Names, phone numbers, emails, event titles, file names, locations and IP addresses are never sent."
        ) {
            Toggle(isOn: $assistantSendsContext) {
                SettingsRowLabel(
                    title: "Send technical context",
                    systemImage: "info.bubble",
                    subtitle: Text("Helps the assistant give precise answers")
                ) {
                    EmptyView()
                }
            }
            .tint(AppColor.primary)
            SettingsDivider()
            Button {
                confirmsClearChats = true
            } label: {
                SettingsRowLabel(title: "Clear chat history", systemImage: "trash", tint: AppColor.error) {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var dataSection: some View {
        SettingsSection(title: "Data") {
            Button {
                showsFileImporter = true
            } label: {
                SettingsRowLabel(
                    title: "Import from file",
                    systemImage: "square.and.arrow.down",
                    subtitle: Text("Contacts (.vcf) and calendars (.ics)")
                ) {
                    if importer.isImporting {
                        ProgressView()
                            .tint(AppColor.primary)
                    } else {
                        SettingsChevron()
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(importer.isImporting)
            SettingsDivider()
            NavigationLink(value: AppRoute.history) {
                SettingsRowLabel(title: "Transfer history", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func clearChatHistory() {
        do {
            let threads = try modelContext.fetch(FetchDescriptor<ChatThread>())
            for thread in threads {
                modelContext.delete(thread)
            }
            try modelContext.delete(model: ChatMessage.self)
            try modelContext.save()
            notice = SettingsNotice(
                title: String(localized: "Chat history cleared"),
                message: String(localized: "All assistant chats were deleted from this device.")
            )
        } catch {
            notice = SettingsNotice(
                title: String(localized: "Couldn't clear chats"),
                message: error.localizedDescription
            )
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            let policy = duplicatePolicy
            Task {
                notice = await importer.importFiles(urls, policy: policy)
            }
        case .failure(let error):
            notice = SettingsNotice(
                title: String(localized: "Couldn't open the file"),
                message: error.localizedDescription
            )
        }
    }
}

/// A simple alert message.
struct SettingsNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Builds the support `mailto:` link with app and iOS versions in the body.
enum SettingsSupportMail {
    @MainActor
    static func url() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "App support")),
            URLQueryItem(name: "body", value: body()),
        ]
        return components.url
    }

    @MainActor
    static func body() -> String {
        let device = UIDevice.current
        let lines = [
            "",
            "",
            "—",
            "App: \(AppConfig.appVersion)",
            "iOS: \(device.systemVersion)",
            "Device: \(deviceModelIdentifier())",
        ]
        return lines.joined(separator: "\n")
    }

    /// Hardware identifier, e.g. "iPhone15,2".
    static func deviceModelIdentifier() -> String {
        var info = utsname()
        uname(&info)
        let identifier = withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        return identifier.isEmpty ? "unknown" : identifier
    }
}

/// About block: logo, version, AI disclaimer and third-party components.
private struct SettingsAboutCard: View {
    var body: some View {
        VStack(spacing: Spacing.m) {
            Illustration.appLogo.image
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: AppColor.primary.opacity(0.18), radius: 10, x: 0, y: 6)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text("About the app")
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text("Version \(AppConfig.appVersion)")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Divider()
                .overlay(AppColor.divider)
            Label {
                Text("Answers are generated by AI and may contain inaccuracies.")
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppColor.primary)
            }
            .font(AppFont.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            Label {
                Text("Includes Apple system frameworks, PremiumKit and ApphudSDK. Third-party components are subject to their respective licenses.")
            } icon: {
                Image(systemName: "doc.plaintext")
                    .foregroundStyle(AppColor.primary)
            }
            .font(AppFont.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .cardStyle(padding: Spacing.xl)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .appRouteDestinations()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
    .modelContainer(for: [TransferRecord.self, ChatThread.self, ChatMessage.self], inMemory: true)
}
