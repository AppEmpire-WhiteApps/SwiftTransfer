import Contacts
import EventKit
import Foundation
import Photos

/// Technical, PII-free context sent with assistant requests (TZ §7.5).
///
/// Contains only versions, the device model identifier, the screen name, transfer counters/state,
/// connection check metrics and permission statuses. Never names, numbers, emails, event titles,
/// file names, locations, IP addresses or tokens.
struct AssistantContext: Encodable, Sendable, Equatable {
    var appVersion: String
    var iosVersion: String
    var deviceModel: String
    var interfaceLanguage: String
    var currentScreen: String
    var transfer: TransferContextInfo?
    var connectionCheck: ConnectionCheckContextInfo?
    var permissions: [String: String]

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case iosVersion = "ios_version"
        case deviceModel = "device_model"
        case interfaceLanguage = "interface_language"
        case currentScreen = "current_screen"
        case transfer
        case connectionCheck = "connection_check"
        case permissions
    }

    /// Snapshot of the current app state.
    @MainActor
    static func current(activity: AppActivityContext?) -> AssistantContext {
        AssistantContext(
            appVersion: AppConfig.appVersion,
            iosVersion: AssistantDeviceInfo.systemVersion,
            deviceModel: AssistantDeviceInfo.modelIdentifier,
            interfaceLanguage: PromptBuilder.interfaceLanguageCode,
            currentScreen: activity?.currentScreen ?? "assistant",
            transfer: activity?.transfer,
            connectionCheck: activity?.connectionCheck,
            permissions: AssistantPermissionSnapshot.current()
        )
    }
}

/// Whether the user allows sending technical context (Settings, on by default).
enum AssistantContextSetting {
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: SettingsKey.assistantSendsContext) as? Bool ?? true
    }
}

enum AssistantDeviceInfo {
    /// e.g. "18.2".
    static var systemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.patchVersion > 0 {
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }
        return "\(version.majorVersion).\(version.minorVersion)"
    }

    /// Hardware model identifier, e.g. "iPhone15,2" (the simulated model on the Simulator).
    static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        return identifier.isEmpty ? "unknown" : identifier
    }
}

/// Read-only permission statuses; never prompts the user.
enum AssistantPermissionSnapshot {
    static func current() -> [String: String] {
        [
            "contacts": contactsStatus(),
            "calendar": eventStatus(EKEventStore.authorizationStatus(for: .event)),
            "reminders": eventStatus(EKEventStore.authorizationStatus(for: .reminder)),
            "photos": photosStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite)),
        ]
    }

    private static func contactsStatus() -> String {
        // Raw values keep this compatible with iOS 17, where `.limited` (4) does not exist yet.
        switch CNContactStore.authorizationStatus(for: .contacts).rawValue {
        case 0: "notDetermined"
        case 1: "restricted"
        case 2: "denied"
        case 3: "authorized"
        case 4: "limited"
        default: "unknown"
        }
    }

    private static func eventStatus(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .fullAccess: "authorized"
        case .writeOnly: "writeOnly"
        @unknown default: "unknown"
        }
    }

    private static func photosStatus(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorized: "authorized"
        case .limited: "limited"
        @unknown default: "unknown"
        }
    }
}
