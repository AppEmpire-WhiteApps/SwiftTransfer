import Foundation

enum TransferRole: String, Codable, Sendable {
    case send
    case receive
}

/// How data travels. Raw values are also used in the assistant context JSON.
enum TransferMethod: String, Codable, Sendable, CaseIterable {
    case webAndroid = "web_android"
    case androidUpload = "android_upload"
    case peer = "peer"
    case externalStorage = "external_storage"
    case storageRestore = "storage_restore"

    var title: LocalizedStringResource {
        switch self {
        case .webAndroid: "Wi-Fi to Android"
        case .androidUpload: "From Android"
        case .peer: "iPhone ↔ iPhone"
        case .externalStorage: "External drive"
        case .storageRestore: "Restore from drive"
        }
    }
}

/// Where the user sends data to.
enum TransferTarget: String, Hashable, Sendable, CaseIterable {
    case android
    /// Legacy value retained for compatibility; not an available destination.
    case iPhone
    case storage

    static let allCases: [TransferTarget] = [.android, .storage]
}

/// Where the user receives data from.
enum TransferOrigin: String, Hashable, Sendable, CaseIterable {
    /// Legacy value retained for compatibility; not an available origin.
    case iPhone
    case android

    static let allCases: [TransferOrigin] = [.android]
}

/// Public transfers are iPhone → Android or Android → iPhone, including drive-based methods.
/// Legacy values remain decodable so existing history is never discarded.
enum TransferDirectionPolicy {
    static func allows(target: TransferTarget) -> Bool {
        target != .iPhone
    }

    static func allows(origin: TransferOrigin) -> Bool {
        origin == .android
    }

    static func allows(method: TransferMethod) -> Bool {
        method != .peer
    }
}

/// Entry point of the full-screen transfer flow. A nil target/origin shows the chooser screen.
enum TransferFlowStart: Identifiable, Hashable, Sendable {
    case send(TransferTarget?)
    case receive(TransferOrigin?)

    /// Reject retired starts to their chooser, never silently choose another transfer.
    var availableStart: TransferFlowStart {
        switch self {
        case .send(let target?) where !TransferDirectionPolicy.allows(target: target):
            .send(nil)
        case .receive(let origin?) where !TransferDirectionPolicy.allows(origin: origin):
            .receive(nil)
        default:
            self
        }
    }

    var id: String {
        switch self {
        case .send(let target): "send-\(target?.rawValue ?? "choose")"
        case .receive(let origin): "receive-\(origin?.rawValue ?? "choose")"
        }
    }
}

enum DuplicatePolicy: String, Codable, Sendable, CaseIterable {
    case skip
    case addAll

    var title: LocalizedStringResource {
        switch self {
        case .skip: "Skip duplicates"
        case .addAll: "Add everything"
        }
    }
}

enum MediaQuality: String, Codable, Sendable, CaseIterable {
    case original
    case compatible

    var title: LocalizedStringResource {
        switch self {
        case .original: "Original (HEIC/HEVC)"
        case .compatible: "Compatible (JPEG/H.264)"
        }
    }
}

enum TransferStatus: String, Codable, Sendable {
    case completed
    case partial
    case failed
    case cancelled
}

/// Shared persisted settings keys (@AppStorage).
enum SettingsKey {
    static let onboardingCompleted = "onboardingCompleted"
    static let defaultMediaQuality = "defaultMediaQuality"
    static let duplicatePolicy = "duplicatePolicy"
    static let keepScreenAwake = "keepScreenAwake"
    static let batteryReminder = "batteryReminder"
    static let assistantSendsContext = "assistantSendsContext"
}
