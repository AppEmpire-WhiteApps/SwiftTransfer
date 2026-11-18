import EventKit
import Foundation

/// Adds events from ICS files to a "Transferred" calendar (or the default calendar).
/// Never modifies or deletes existing events.
final class CalendarImporter {
    struct Outcome {
        var imported = 0
        var skipped = 0
        var created: [String] = []
    }

    private let store = EKEventStore()
    private var index: CalendarDuplicateIndex?
    private var target: EKCalendar?

    init() {}

    func importEvents(_ events: [ICSEvent], policy: DuplicatePolicy) throws -> Outcome {
        var outcome = Outcome()
        guard !events.isEmpty else { return outcome }
        let calendar = try targetCalendar()
        if policy == .skip && index == nil {
            index = existingIndex(around: events)
        }

        let masters = events.filter { $0.recurrenceID == nil }
        let overrides = events.filter { $0.recurrenceID != nil }
        var createdByUID: [String: EKEvent] = [:]
        var pending: [EKEvent] = []

        for event in masters {
            if policy == .skip, index?.containsEvent(uid: event.uid, title: event.summary, start: event.start) == true {
                outcome.skipped += 1
                continue
            }
            let ekEvent = makeEvent(from: event, in: calendar)
            try store.save(ekEvent, span: .futureEvents, commit: false)
            index?.insertEvent(uid: event.uid, title: event.summary, start: event.start)
            createdByUID[event.uid] = ekEvent
            pending.append(ekEvent)
            if pending.count >= 50 {
                try commit(&pending, into: &outcome)
            }
        }
        try commit(&pending, into: &outcome)

        for event in overrides {
            if policy == .skip, index?.containsEvent(uid: event.uid, title: event.summary, start: event.start) == true {
                outcome.skipped += 1
                continue
            }
            if let master = createdByUID[event.uid], let occurrence = occurrence(of: master, at: event.recurrenceID, in: calendar) {
                apply(event, to: occurrence)
                try store.save(occurrence, span: .thisEvent, commit: true)
            } else {
                let standalone = makeEvent(from: event, in: calendar)
                try store.save(standalone, span: .thisEvent, commit: false)
                pending.append(standalone)
            }
            index?.insertEvent(uid: event.uid, title: event.summary, start: event.start)
        }
        try commit(&pending, into: &outcome)
        return outcome
    }

    /// Deletes only the given events ("Undo import").
    func delete(identifiers: [String]) throws {
        for identifier in identifiers {
            guard let event = store.event(withIdentifier: identifier) else { continue }
            try store.remove(event, span: .futureEvents, commit: false)
        }
        try store.commit()
    }

    // MARK: Private

    private func commit(_ pending: inout [EKEvent], into outcome: inout Outcome) throws {
        guard !pending.isEmpty else { return }
        try store.commit()
        outcome.created += pending.compactMap(\.eventIdentifier)
        outcome.imported += pending.count
        pending.removeAll()
    }

    private func makeEvent(from event: ICSEvent, in calendar: EKCalendar) -> EKEvent {
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.calendar = calendar
        apply(event, to: ekEvent)
        if let recurrence = event.recurrence {
            ekEvent.recurrenceRules = [EventKitMapping.rule(from: recurrence)]
        }
        return ekEvent
    }

    private func apply(_ event: ICSEvent, to ekEvent: EKEvent) {
        ekEvent.title = event.summary
        ekEvent.isAllDay = event.isAllDay
        ekEvent.timeZone = event.isAllDay ? nil : event.timeZone
        ekEvent.startDate = event.start
        // iCalendar all-day ends are exclusive (next midnight); EventKit expects the last day.
        ekEvent.endDate = event.isAllDay ? max(event.start, event.end.addingTimeInterval(-1)) : event.end
        ekEvent.location = event.location
        ekEvent.notes = event.notes
        ekEvent.url = event.url
        ekEvent.alarms = event.alarms.isEmpty ? nil : event.alarms.map(EventKitMapping.ekAlarm(from:))
    }

    private func occurrence(of master: EKEvent, at date: Date?, in calendar: EKCalendar) -> EKEvent? {
        guard let date, let identifier = master.eventIdentifier else { return nil }
        let predicate = store.predicateForEvents(
            withStart: date.addingTimeInterval(-86_400),
            end: date.addingTimeInterval(86_400),
            calendars: [calendar]
        )
        return store.events(matching: predicate).first { candidate in
            candidate.eventIdentifier == identifier && abs(candidate.occurrenceDate.timeIntervalSince(date)) < 60
        }
    }

    private func targetCalendar() throws -> EKCalendar {
        if let target {
            return target
        }
        let title = String(localized: "Transferred")
        if let existing = store.calendars(for: .event).first(where: { $0.title == title && $0.allowsContentModifications }) {
            target = existing
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = title
        calendar.cgColor = CGColor(srgbRed: 0.12, green: 0.42, blue: 1, alpha: 1)
        let candidates = [store.defaultCalendarForNewEvents?.source]
            + store.sources.filter { $0.sourceType == .local }
            + store.sources.filter { $0.sourceType == .calDAV }
        for source in candidates.compactMap({ $0 }) {
            calendar.source = source
            if (try? store.saveCalendar(calendar, commit: true)) != nil {
                target = calendar
                return calendar
            }
        }
        guard let fallback = store.defaultCalendarForNewEvents else {
            throw ImportError.noWritableCalendar
        }
        target = fallback
        return fallback
    }

    private func existingIndex(around events: [ICSEvent]) -> CalendarDuplicateIndex {
        var index = CalendarDuplicateIndex()
        guard let earliest = events.map(\.start).min(), let latest = events.map(\.start).max() else { return index }
        let calendars = store.calendars(for: .event)
        guard !calendars.isEmpty else { return index }
        var chunkStart = earliest.addingTimeInterval(-86_400)
        let end = latest.addingTimeInterval(86_400)
        while chunkStart < end {
            let chunkEnd = min(Calendar.current.date(byAdding: .year, value: 1, to: chunkStart) ?? end, end)
            let predicate = store.predicateForEvents(withStart: chunkStart, end: chunkEnd, calendars: calendars)
            for event in store.events(matching: predicate) {
                index.insertEvent(uid: event.calendarItemExternalIdentifier, title: event.title ?? "", start: event.startDate)
            }
            chunkStart = chunkEnd
        }
        return index
    }
}

enum ImportError: LocalizedError {
    case noAccess(DataCategory)
    case noWritableCalendar
    case notEnoughSpace

    var errorDescription: String? {
        switch self {
        case .noAccess(let category):
            String(localized: "No access to \(String(localized: category.title)). Allow access in Settings.")
        case .noWritableCalendar:
            String(localized: "No calendar or list that can be edited was found.")
        case .notEnoughSpace:
            String(localized: "Not enough free space on this device.")
        }
    }
}
