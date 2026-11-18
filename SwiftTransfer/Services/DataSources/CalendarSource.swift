import EventKit
import Foundation

/// An event calendar the user can choose on the selection screen.
struct CalendarInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let accountTitle: String
    /// Subscribed or birthday calendars: read-only feeds, off by default.
    let isReadOnlyFeed: Bool
    /// sRGB components for a small color dot.
    let color: [Double]
}

/// Read-only access to calendar events. Has no write methods (TZ §4.10).
actor CalendarSource {
    init() {}

    func calendars() -> [CalendarInfo] {
        let store = EKEventStore()
        return store.calendars(for: .event).map { calendar in
            CalendarInfo(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                accountTitle: calendar.source?.title ?? "",
                isReadOnlyFeed: Self.isReadOnlyFeed(calendar),
                color: Self.components(of: calendar.cgColor)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isReadOnlyFeed != rhs.isReadOnlyFeed {
                return !lhs.isReadOnlyFeed
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    /// Events of the selected calendars in the period, as ICS values.
    /// Recurring events are returned once (with their RRULE), detached occurrences separately.
    func events(calendarIDs: Set<String>?, interval: DateInterval) -> [ICSEvent] {
        var result: [ICSEvent] = []
        forEachUniqueEvent(calendarIDs: calendarIDs, interval: interval) { event in
            result.append(EventKitMapping.event(from: event))
        }
        return result
    }

    func count(calendarIDs: Set<String>?, interval: DateInterval) -> Int {
        var count = 0
        forEachUniqueEvent(calendarIDs: calendarIDs, interval: interval) { _ in
            count += 1
        }
        return count
    }

    /// Period of the selection: last year + future (5 years), all (20 years back, 10 ahead) or custom.
    static func interval(for selection: TransferSelection, now: Date = .now) -> DateInterval {
        let calendar = Calendar.current
        switch selection.calendarRange {
        case .lastYearAndFuture:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            let end = calendar.date(byAdding: .year, value: 5, to: now) ?? now
            return DateInterval(start: start, end: end)
        case .all:
            let start = calendar.date(byAdding: .year, value: -20, to: now) ?? now
            let end = calendar.date(byAdding: .year, value: 10, to: now) ?? now
            return DateInterval(start: start, end: end)
        case .custom:
            let start = selection.customCalendarStart ?? calendar.date(byAdding: .year, value: -1, to: now) ?? now
            let proposedEnd = selection.customCalendarEnd ?? now
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(start, proposedEnd))) ?? proposedEnd
            return DateInterval(start: calendar.startOfDay(for: start), end: end)
        }
    }

    static func isReadOnlyFeed(_ calendar: EKCalendar) -> Bool {
        calendar.type == .subscription || calendar.type == .birthday
    }

    // MARK: Private

    private func forEachUniqueEvent(
        calendarIDs: Set<String>?,
        interval: DateInterval,
        _ body: (EKEvent) -> Void
    ) {
        let store = EKEventStore()
        let calendars = store.calendars(for: .event).filter { calendar in
            if let calendarIDs {
                return calendarIDs.contains(calendar.calendarIdentifier)
            }
            return !Self.isReadOnlyFeed(calendar)
        }
        guard !calendars.isEmpty else { return }

        var seen = Set<String>()
        let calendar = Calendar.current
        var chunkStart = interval.start
        // EventKit limits predicate spans, so query one year at a time.
        while chunkStart < interval.end {
            let chunkEnd = min(calendar.date(byAdding: .year, value: 1, to: chunkStart) ?? interval.end, interval.end)
            let predicate = store.predicateForEvents(withStart: chunkStart, end: chunkEnd, calendars: calendars)
            let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
            for event in events {
                guard seen.insert(Self.uniqueKey(event)).inserted else { continue }
                autoreleasepool {
                    body(event)
                }
            }
            chunkStart = chunkEnd
        }
    }

    private static func uniqueKey(_ event: EKEvent) -> String {
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        if event.isDetached {
            return identifier + "|" + String(event.occurrenceDate.timeIntervalSince1970)
        }
        if event.hasRecurrenceRules {
            return identifier
        }
        return identifier + "|" + String(event.startDate.timeIntervalSince1970)
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
