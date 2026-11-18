import Observation
import SwiftUI

enum AppTab: Hashable {
    case home
    case guides
    case assistant
    case settings
}

/// Pushable destinations shared by the tab navigation stacks.
enum AppRoute: Hashable {
    case connectionCheck
    case externalStorage
    case guide(GuideID)
    case history
}

/// Actions the assistant can suggest as buttons. Raw values match the JSON schema in TZ §7.7.
enum AssistantAction: String, CaseIterable, Codable, Sendable {
    case openConnectionCheck = "open_connection_check"
    case startSend = "start_send"
    case startReceive = "start_receive"
    case openStorageExport = "open_storage_export"
    case openGuideWifiGalaxy = "open_guide_wifi_galaxy"
    case openGuideCableGalaxy = "open_guide_cable_galaxy"
    case openGuideStorage = "open_guide_storage"
    case openGuideAndroidIphone = "open_guide_android_iphone"
    case openGuideHotspot = "open_guide_hotspot"
    case openGuideImportSamsung = "open_guide_import_samsung"
    case openGuideNotTransferable = "open_guide_not_transferable"
    case openSettingsPermissions = "open_settings_permissions"

    var title: LocalizedStringResource {
        switch self {
        case .openConnectionCheck: "Check connection"
        case .startSend: "Send data"
        case .startReceive: "Receive data"
        case .openStorageExport: "Cable & drive"
        case .openGuideWifiGalaxy: "Guide: Wi-Fi to Android"
        case .openGuideCableGalaxy: "Guide: cable to Android"
        case .openGuideStorage: "Guide: external drive"
        case .openGuideAndroidIphone: "Guide: Android to iPhone"
        case .openGuideHotspot: "Guide: personal hotspot"
        case .openGuideImportSamsung: "Guide: import on Android"
        case .openGuideNotTransferable: "What can't be moved"
        case .openSettingsPermissions: "Open Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .openConnectionCheck: "wifi"
        case .startSend: "arrow.up.circle"
        case .startReceive: "arrow.down.circle"
        case .openStorageExport: "externaldrive"
        case .openSettingsPermissions: "gear"
        default: "book"
        }
    }

    var guide: GuideID? {
        switch self {
        case .openGuideWifiGalaxy: .wifiGalaxy
        case .openGuideCableGalaxy: .cableGalaxy
        case .openGuideStorage: .storage
        case .openGuideAndroidIphone: .androidIphone
        case .openGuideHotspot: .hotspot
        case .openGuideImportSamsung: .importSamsung
        case .openGuideNotTransferable: .notTransferable
        default: nil
        }
    }
}

/// Opens the assistant as a sheet with an optional pre-filled draft message.
struct AssistantLaunch: Identifiable, Hashable {
    let id = UUID()
    var draft: String?
}

/// App-wide navigation: tabs, per-tab stacks, the full-screen transfer flow and the assistant sheet.
@MainActor
@Observable
final class AppRouter {
    let premiumAccess: PremiumAccess
    var selectedTab: AppTab = .home
    var homePath = NavigationPath()
    var guidesPath = NavigationPath()
    var settingsPath = NavigationPath()
    var transferFlow: TransferFlowStart?
    var assistantSheet: AssistantLaunch?

    init(access: PremiumAccess = PremiumAccess()) {
        premiumAccess = access
    }

    func startTransfer(_ start: TransferFlowStart) {
        assistantSheet = nil
        transferFlow = start.availableStart
    }

    /// Opens the assistant sheet over the current screen (used outside the Assistant tab).
    func askAssistant(draft: String? = nil) {
        assistantSheet = AssistantLaunch(draft: draft)
    }

    func openGuide(_ guide: GuideID) {
        guard premiumAccess.authorizeGuide(guide) else { return }
        showOnHome(.guide(guide), tab: .guides)
    }

    func open(_ route: AppRoute) {
        if case .guide(let guide) = route, !premiumAccess.authorizeGuide(guide) { return }
        showOnHome(route, tab: .home)
    }

    func perform(_ action: AssistantAction) {
        if let guide = action.guide {
            openGuide(guide)
            return
        }
        switch action {
        case .openConnectionCheck:
            open(.connectionCheck)
        case .startSend:
            startTransfer(.send(nil))
        case .startReceive:
            startTransfer(.receive(nil))
        case .openStorageExport:
            open(.externalStorage)
        case .openSettingsPermissions:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    private func showOnHome(_ route: AppRoute, tab: AppTab) {
        assistantSheet = nil
        transferFlow = nil
        selectedTab = tab
        switch tab {
        case .guides:
            guidesPath = NavigationPath()
            guidesPath.append(route)
        default:
            homePath = NavigationPath()
            homePath.append(route)
        }
    }
}

extension View {
    /// Registers destinations for `AppRoute` inside a NavigationStack.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .connectionCheck:
                ConnectionCheckView()
            case .externalStorage:
                ExternalStorageView()
            case .guide(let guide):
                GuideDetailView(guide: guide)
            case .history:
                HistoryView()
            }
        }
    }
}
