import Foundation

// Plain value types describing iCalendar (RFC 5545) content.
// EventKit objects are mapped to these values so that writing and parsing stay unit-testable.

/// Recurrence frequency (`FREQ`).
enum ICSFrequency: String, Sendable, Hashable, CaseIterable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case yearly = "YEARLY"
}

/// A `BYDAY` item such as `MO`, `2TU` or `-1FR`.
struct ICSWeekday: Sendable, Hashable {
    /// 1 = Sunday … 7 = Saturday (same numbering as `EKWeekday` and `Calendar`).
    var weekday: Int
    /// 0 means every week; otherwise an ordinal like 2 or -1.
    var ordinal: Int = 0
}

/// A recurrence rule (`RRULE`).
struct ICSRecurrence: Sendable, Hashable {
    var frequency: ICSFrequency
    var interval: Int = 1
    var count: Int?
    var until: Date?
    var daysOfWeek: [ICSWeekday] = []
    var daysOfMonth: [Int] = []
    var monthsOfYear: [Int] = []
    var weeksOfYear: [Int] = []
    var daysOfYear: [Int] = []
    var setPositions: [Int] = []
    /// `WKST`, 1 = Sunday … 7 = Saturday. Nil when not specified.
    var weekStart: Int?
}

/// A display alarm (`VALARM`).
struct ICSAlarm: Sendable, Hashable {
    enum Trigger: Sendable, Hashable {
        /// Seconds relative to the start (negative = before).
        case relative(TimeInterval)
        case absolute(Date)
    }

    var trigger: Trigger
    var description = "Reminder"
}

/// A calendar event (`VEVENT`).
struct ICSEvent: Sendable, Hashable {
    var uid: String
    var summary: String
    var start: Date
    /// Exclusive end. For all-day events this is midnight of the day after the last day.
    var end: Date
    var isAllDay = false
    /// Nil means floating local time (or a date for all-day events).
    var timeZone: TimeZone?
    var location: String?
    var notes: String?
    var url: URL?
    var recurrence: ICSRecurrence?
    var exceptionDates: [Date] = []
    /// Set for a modified occurrence of a recurring event (`RECURRENCE-ID`).
    var recurrenceID: Date?
    var alarms: [ICSAlarm] = []
}

/// A reminder (`VTODO`).
struct ICSTodo: Sendable, Hashable {
    var uid: String
    var summary: String
    var notes: String?
    var due: Date?
    var dueIsAllDay = false
    /// Nil means floating local time.
    var dueTimeZone: TimeZone?
    /// 0 = undefined, 1 = highest … 9 = lowest.
    var priority = 0
    var isCompleted = false
    var completionDate: Date?
    var recurrence: ICSRecurrence?
    var alarms: [ICSAlarm] = []
    /// Name of the reminder list, written as `CATEGORIES`.
    var listName: String?
}

/// Parsed content of an `.ics` file.
struct ICSCalendar: Sendable, Hashable {
    var name: String?
    var events: [ICSEvent] = []
    var todos: [ICSTodo] = []
}

/// Date/time formatting helpers shared by the writer and the parser.
enum ICSDateFormat {
    static let utc = TimeZone(secondsFromGMT: 0) ?? TimeZone.current

    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func isUTC(_ timeZone: TimeZone) -> Bool {
        let utcNames: Set<String> = ["GMT", "UTC", "Etc/UTC", "Etc/GMT", "Z"]
        return utcNames.contains(timeZone.identifier)
    }

    /// `yyyyMMdd'T'HHmmss` in the given zone.
    static func dateTime(_ date: Date, in timeZone: TimeZone) -> String {
        let parts = calendar(in: timeZone).dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return pad(parts.year, 4) + pad(parts.month, 2) + pad(parts.day, 2)
            + "T" + pad(parts.hour, 2) + pad(parts.minute, 2) + pad(parts.second, 2)
    }

    /// `yyyyMMdd` in the given zone.
    static func date(_ date: Date, in timeZone: TimeZone) -> String {
        let parts = calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        return pad(parts.year, 4) + pad(parts.month, 2) + pad(parts.day, 2)
    }

    /// `yyyyMMdd'T'HHmmss'Z'`.
    static func utcDateTime(_ date: Date) -> String {
        dateTime(date, in: utc) + "Z"
    }

    private static func pad(_ value: Int?, _ width: Int) -> String {
        let text = String(value ?? 0)
        guard text.count < width else { return text }
        return String(repeating: "0", count: width - text.count) + text
    }
}
