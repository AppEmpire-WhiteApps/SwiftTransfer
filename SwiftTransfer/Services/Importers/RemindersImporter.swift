import EventKit
import Foundation

/// Adds reminders from ICS files into lists with the same names (created when missing)
/// or a "Transferred" list. Never modifies or deletes existing reminders.
final class RemindersImporter {
    struct Outcome {
        var imported = 0
        var skipped = 0
        var created: [String] = []
    }

    private let store = EKEventStore()
    private var index: CalendarDuplicateIndex?
    private var lists: [String: EKCalendar] = [:]

    init() {}

    func importTodos(_ todos: [ICSTodo], policy: DuplicatePolicy) async throws -> Outcome {
        var outcome = Outcome()
        guard !todos.isEmpty else { return outcome }
        if policy == .skip && index == nil {
            index = await existingIndex()
        }

        var pending: [EKReminder] = []
        for todo in todos {
            if policy == .skip, index?.containsReminder(title: todo.summary, due: todo.due) == true {
                outcome.skipped += 1
                continue
            }
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = try list(named: todo.listName)
            reminder.title = todo.summary
            reminder.notes = todo.notes
            reminder.priority = max(0, min(todo.priority, 9))
            reminder.dueDateComponents = EventKitMapping.dueComponents(for: todo)
            if let recurrence = todo.recurrence, todo.due != nil {
                reminder.recurrenceRules = [EventKitMapping.rule(from: recurrence)]
            }
            if !todo.alarms.isEmpty {
                reminder.alarms = todo.alarms.map(EventKitMapping.ekAlarm(from:))
            }
            if todo.isCompleted {
                reminder.isCompleted = true
                reminder.completionDate = todo.completionDate ?? .now
            }
            try store.save(reminder, commit: false)
            index?.insertReminder(title: todo.summary, due: todo.due)
            pending.append(reminder)
        }
        if !pending.isEmpty {
            try store.commit()
            outcome.created = pending.map(\.calendarItemIdentifier)
            outcome.imported = pending.count
        }
        return outcome
    }

    /// Deletes only the given reminders ("Undo import").
    func delete(identifiers: [String]) throws {
        for identifier in identifiers {
            guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else { continue }
            try store.remove(reminder, commit: false)
        }
        try store.commit()
    }

    // MARK: Private

    private func list(named name: String?) throws -> EKCalendar {
        let title = (name?.isEmpty == false ? name : nil) ?? String(localized: "Transferred")
        if let cached = lists[title] {
            return cached
        }
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == title && $0.allowsContentModifications }) {
            lists[title] = existing
            return existing
        }
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = title
        let candidates = [store.defaultCalendarForNewReminders()?.source]
            + store.sources.filter { $0.sourceType == .calDAV }
            + store.sources.filter { $0.sourceType == .local }
        for source in candidates.compactMap({ $0 }) {
            calendar.source = source
            if (try? store.saveCalendar(calendar, commit: true)) != nil {
                lists[title] = calendar
                return calendar
            }
        }
        guard let fallback = store.defaultCalendarForNewReminders() else {
            throw ImportError.noWritableCalendar
        }
        lists[title] = fallback
        return fallback
    }

    private func existingIndex() async -> CalendarDuplicateIndex {
        let predicate = store.predicateForReminders(in: nil)
        let keys: [(String, Date?)] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let result = (reminders ?? []).map { reminder -> (String, Date?) in
                    let due = reminder.dueDateComponents.flatMap { components -> Date? in
                        var calendar = Calendar(identifier: .gregorian)
                        calendar.timeZone = components.timeZone ?? .current
                        return calendar.date(from: components)
                    }
                    return (reminder.title ?? "", due)
                }
                continuation.resume(returning: result)
            }
        }
        var index = CalendarDuplicateIndex()
        for (title, due) in keys {
            index.insertReminder(title: title, due: due)
        }
        return index
    }
}
