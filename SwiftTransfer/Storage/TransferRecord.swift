import Foundation
import SwiftData

/// One finished (or interrupted) transfer shown in History.
@Model
final class TransferRecord {
    var id: UUID
    var date: Date
    var roleRaw: String
    var methodRaw: String
    var peerName: String
    /// Item counts keyed by `DataCategory.rawValue`.
    var categoryCounts: [String: Int]
    var totalBytes: Int64
    var duration: TimeInterval
    var statusRaw: String
    var errorSummaries: [String]
    var createdContactIDs: [String]
    var createdEventIDs: [String]
    var createdReminderIDs: [String]
    var createdAssetIDs: [String]
    var importUndone: Bool

    init(
        date: Date = .now,
        role: TransferRole,
        method: TransferMethod,
        peerName: String,
        categoryCounts: [DataCategory: Int],
        totalBytes: Int64,
        duration: TimeInterval,
        status: TransferStatus,
        errorSummaries: [String] = [],
        created: CreatedIdentifiers = CreatedIdentifiers()
    ) {
        self.id = UUID()
        self.date = date
        self.roleRaw = role.rawValue
        self.methodRaw = method.rawValue
        self.peerName = peerName
        self.categoryCounts = Dictionary(uniqueKeysWithValues: categoryCounts.map { ($0.key.rawValue, $0.value) })
        self.totalBytes = totalBytes
        self.duration = duration
        self.statusRaw = status.rawValue
        self.errorSummaries = errorSummaries
        self.createdContactIDs = created.contacts
        self.createdEventIDs = created.events
        self.createdReminderIDs = created.reminders
        self.createdAssetIDs = created.assets
        self.importUndone = false
    }

    var role: TransferRole { TransferRole(rawValue: roleRaw) ?? .send }
    var method: TransferMethod { TransferMethod(rawValue: methodRaw) ?? .peer }
    var status: TransferStatus { TransferStatus(rawValue: statusRaw) ?? .completed }

    var created: CreatedIdentifiers {
        CreatedIdentifiers(
            contacts: createdContactIDs,
            events: createdEventIDs,
            reminders: createdReminderIDs,
            assets: createdAssetIDs
        )
    }

    var counts: [DataCategory: Int] {
        var result: [DataCategory: Int] = [:]
        for (key, value) in categoryCounts {
            if let category = DataCategory(rawValue: key) {
                result[category] = value
            }
        }
        return result
    }
}
