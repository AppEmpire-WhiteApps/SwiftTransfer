import Foundation
import SwiftUI

/// Pure helpers for the transfer history (testable without SwiftData).
enum HistoryRules {
    /// "Undo import" is offered for this long after a receive.
    static let undoWindow: TimeInterval = 24 * 60 * 60

    /// Repeat a supported direction and method; retired peer history has no repeat action.
    static func repeatStart(role: TransferRole, method: TransferMethod) -> TransferFlowStart? {
        guard TransferDirectionPolicy.allows(method: method) else { return nil }
        switch (role, method) {
        case (.send, .webAndroid):
            return .send(.android)
        case (.send, .externalStorage):
            return .send(.storage)
        case (.send, _):
            return .send(nil)
        case (.receive, .androidUpload), (.receive, .webAndroid):
            return .receive(.android)
        case (.receive, _):
            return .receive(nil)
        }
    }

    static func canUndoImport(
        role: TransferRole,
        date: Date,
        created: CreatedIdentifiers,
        importUndone: Bool,
        now: Date = .now
    ) -> Bool {
        guard role == .receive, !importUndone, !created.historyIsEmpty else { return false }
        let age = now.timeIntervalSince(date)
        return age >= 0 && age < undoWindow
    }
}

extension CreatedIdentifiers {
    var historyIsEmpty: Bool {
        contacts.isEmpty && events.isEmpty && reminders.isEmpty && assets.isEmpty
    }

    var historyTotalCount: Int {
        contacts.count + events.count + reminders.count + assets.count
    }
}

extension TransferRecord {
    var historyRepeatStart: TransferFlowStart? {
        HistoryRules.repeatStart(role: role, method: method)
    }

    func historyCanUndoImport(now: Date = .now) -> Bool {
        HistoryRules.canUndoImport(role: role, date: date, created: created, importUndone: importUndone, now: now)
    }

    var historyTotalItems: Int {
        categoryCounts.values.reduce(0, +)
    }
}

extension TransferStatus {
    var historyTitle: LocalizedStringResource {
        switch self {
        case .completed: "Completed"
        case .partial: "Partly completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    var historyColor: Color {
        switch self {
        case .completed: AppColor.success
        case .partial: AppColor.warning
        case .failed: AppColor.error
        case .cancelled: AppColor.textSecondary
        }
    }

    var historyIllustration: Illustration {
        switch self {
        case .completed: .success
        case .partial: .partialSuccess
        case .failed, .cancelled: .errorConnection
        }
    }
}

extension TransferRole {
    var historySystemImage: String {
        switch self {
        case .send: "arrow.up.right"
        case .receive: "arrow.down.left"
        }
    }
}
