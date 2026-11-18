import EventKit
import Foundation

/// A reminder list the user can choose on the selection screen.
struct ReminderListInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let accountTitle: String
    let color: [Double]
}

/// Read-only access to reminders. Has no write methods (TZ §4.10).
actor RemindersSource {
    init() {}

    func lists() -> [ReminderListInfo] {
        let store = EKEventStore()
        return store.calendars(for: .reminder).map { calendar in
            ReminderListInfo(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                accountTitle: calendar.source?.title ?? "",
                color: Self.components(of: calendar.cgColor)
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Reminders grouped by list, mapped to ICS values.
    func reminders(listIDs: Set<String>?, includeCompleted: Bool) async -> [ReminderListText] {
        let store = EKEventStore()
        let calendars = store.calendars(for: .reminder).filter { listIDs?.contains($0.calendarIdentifier) ?? true }
        guard !calendars.isEmpty else { return [] }
        let titles = Dictionary(uniqueKeysWithValues: calendars.map { ($0.calendarIdentifier, $0.title) })
        let order = calendars.map(\.calendarIdentifier)

        let predicate = includeCompleted
            ? store.predicateForReminders(in: calendars)
            : store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)

        let grouped: [String: [ICSTodo]] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                var result: [String: [ICSTodo]] = [:]
                for reminder in reminders ?? [] {
                    let listID = reminder.calendar?.calendarIdentifier ?? ""
                    let todo = EventKitMapping.todo(from: reminder, listName: titles[listID])
                    result[listID, default: []].append(todo)
                }
                continuation.resume(returning: result)
            }
        }
        withExtendedLifetime(store) {}
        return order.compactMap { listID in
            guard let items = grouped[listID], !items.isEmpty else { return nil }
            return ReminderListText(title: titles[listID] ?? "", items: items)
        }
    }

    func count(listIDs: Set<String>?, includeCompleted: Bool) async -> Int {
        await reminders(listIDs: listIDs, includeCompleted: includeCompleted).reduce(0) { $0 + $1.items.count }
    }

    private static func components(of color: CGColor?) -> [Double] {
        guard let color,
              let converted = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let parts = converted.components, parts.count >= 3 else {
            return [0.12, 0.42, 1]
        }
        return parts.prefix(3).map { Double($0) }
    }
}
