import AVFoundation
import Contacts
import EventKit
import Photos
import UIKit

/// System permissions used by the app.
enum PermissionKind: String, Sendable, CaseIterable, Identifiable {
    case contacts
    case calendar
    case reminders
    /// Read and write access to the photo library (sender side).
    case photos
    /// Add-only access to the photo library (receiver side).
    case photosAddOnly
    case camera

    var id: String { rawValue }

    /// Permission needed to read a category, nil for user-picked files.
    static func reading(_ category: DataCategory) -> PermissionKind? {
        switch category {
        case .contacts: .contacts
        case .calendar: .calendar
        case .reminders: .reminders
        case .photos, .videos: .photos
        case .files: nil
        }
    }

    /// Permission needed to import a category on this device, nil for files.
    static func importing(_ category: DataCategory) -> PermissionKind? {
        switch category {
        case .contacts: .contacts
        case .calendar: .calendar
        case .reminders: .reminders
        case .photos, .videos: .photosAddOnly
        case .files: nil
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .contacts: "Contacts"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .photos: "Photos and videos"
        case .photosAddOnly: "Save to Photos"
        case .camera: "Camera"
        }
    }

    /// Two lines shown on the permission primer.
    var primerMessage: LocalizedStringResource {
        switch self {
        case .contacts:
            "The app copies your contacts to the new device. Contacts on this iPhone stay unchanged."
        case .calendar:
            "The app copies your calendar events. Nothing is changed or deleted here."
        case .reminders:
            "The app copies your reminder lists. Your reminders stay on this device too."
        case .photos:
            "The app copies photos and videos in their original quality. Originals stay in place."
        case .photosAddOnly:
            "The app saves received photos and videos to your library. Nothing existing is changed."
        case .camera:
            "The camera is used only to scan the QR code shown on the other device."
        }
    }
}

/// Authorization state normalized across frameworks.
enum PermissionState: Sendable, Equatable {
    case notDetermined
    case authorized
    /// Limited access (selected photos, or selected contacts on iOS 18+).
    case limited
    case denied
    case restricted

    var allowsAccess: Bool {
        self == .authorized || self == .limited
    }

    var isBlocked: Bool {
        self == .denied || self == .restricted
    }
}

/// Reads and requests system permissions. Stateless and safe to use from any context.
struct PermissionsService: Sendable {
    init() {}

    func status(_ kind: PermissionKind) -> PermissionState {
        switch kind {
        case .contacts:
            return Self.contactsState(CNContactStore.authorizationStatus(for: .contacts))
        case .calendar:
            return Self.eventKitState(EKEventStore.authorizationStatus(for: .event))
        case .reminders:
            return Self.eventKitState(EKEventStore.authorizationStatus(for: .reminder))
        case .photos:
            return Self.photosState(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .photosAddOnly:
            let readWrite = Self.photosState(PHPhotoLibrary.authorizationStatus(for: .readWrite))
            if readWrite == .authorized {
                return .authorized
            }
            return Self.photosState(PHPhotoLibrary.authorizationStatus(for: .addOnly))
        case .camera:
            return Self.cameraState(AVCaptureDevice.authorizationStatus(for: .video))
        }
    }

    /// Shows the system prompt when the state is not determined; otherwise returns the current state.
    func request(_ kind: PermissionKind) async -> PermissionState {
        let current = status(kind)
        guard current == .notDetermined else { return current }
        switch kind {
        case .contacts:
            _ = await Self.requestContacts()
        case .calendar:
            _ = await Self.requestEvents(.event)
        case .reminders:
            _ = await Self.requestEvents(.reminder)
        case .photos:
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        case .photosAddOnly:
            _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        case .camera:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        return status(kind)
    }

    /// Opens the app page in the Settings app.
    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Requests

    private static func requestContacts() async -> Bool {
        await withCheckedContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func requestEvents(_ type: EKEntityType) async -> Bool {
        await withCheckedContinuation { continuation in
            let store = EKEventStore()
            if type == .event {
                store.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            } else {
                store.requestFullAccessToReminders { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: Mapping

    static func contactsState(_ status: CNAuthorizationStatus) -> PermissionState {
        if #available(iOS 18.0, *), status == .limited {
            return .limited
        }
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        default: return .authorized
        }
    }

    static func eventKitState(_ status: EKAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .fullAccess: return .authorized
        case .writeOnly: return .denied
        default: return .notDetermined
        }
    }

    static func photosState(_ status: PHAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        case .limited: return .limited
        @unknown default: return .denied
        }
    }

    static func cameraState(_ status: AVAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .denied
        }
    }
}
