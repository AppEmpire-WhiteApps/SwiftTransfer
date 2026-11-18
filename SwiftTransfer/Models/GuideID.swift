import Foundation

/// Identifiers of the built-in step-by-step guides.
enum GuideID: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case wifiGalaxy = "wifi_galaxy"
    case cableGalaxy = "cable_galaxy"
    case storage = "storage"
    case androidIphone = "android_iphone"
    case hotspot = "hotspot"
    case importSamsung = "import_samsung"
    case notTransferable = "not_transferable"
    case faq = "faq"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .wifiGalaxy: "iPhone to Android over Wi-Fi"
        case .cableGalaxy: "iPhone to Android by cable"
        case .storage: "Using an external drive"
        case .androidIphone: "Android to iPhone"
        case .hotspot: "Transfer without a router"
        case .importSamsung: "Import files on Android"
        case .notTransferable: "What iOS can't transfer"
        case .faq: "Frequently asked questions"
        }
    }

    /// Approximate time to follow the guide, in minutes.
    var minutes: Int {
        switch self {
        case .wifiGalaxy, .cableGalaxy, .storage: 5
        case .androidIphone, .hotspot, .importSamsung: 3
        case .notTransferable, .faq: 2
        }
    }

    var cover: Illustration {
        switch self {
        case .wifiGalaxy: .guideWifiGalaxy
        case .cableGalaxy: .guideCableGalaxy
        case .storage: .guideStorage
        case .androidIphone: .guideAndroidIphone
        case .hotspot: .guideHotspot
        case .importSamsung: .guideImportSamsung
        case .notTransferable: .guideNotTransferable
        case .faq: .guideFAQ
        }
    }
}
