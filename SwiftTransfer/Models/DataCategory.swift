import SwiftUI

/// A kind of data the app can move between devices.
enum DataCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case contacts
    case calendar
    case reminders
    case photos
    case videos
    case files

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .contacts: "Contacts"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .photos: "Photos"
        case .videos: "Videos"
        case .files: "Files"
        }
    }

    var illustration: Illustration {
        switch self {
        case .contacts: .contacts
        case .calendar: .calendar
        case .reminders: .reminders
        case .photos: .photos
        case .videos: .videos
        case .files: .files
        }
    }

    var systemImage: String {
        switch self {
        case .contacts: "person.crop.circle"
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .photos: "photo.on.rectangle"
        case .videos: "video"
        case .files: "folder"
        }
    }

    /// Top-level folder name used in packages, ZIP archives and the web receiver.
    var folderName: String {
        switch self {
        case .contacts: "Contacts"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .photos: "Photos"
        case .videos: "Videos"
        case .files: "Files"
        }
    }
}
