import Foundation

/// Writes RFC 5545 iCalendar documents from plain `ICSEvent` / `ICSTodo` values.
struct ICSWriter: Sendable {
    var productID = "-//SwiftTransfer//SwiftTransfer 1.0//EN"
    /// Value of `DTSTAMP` for every component.
    var stamp = Date()
    /// Zone used to format floating times and all-day dates.
    var floatingTimeZone = TimeZone.current

    static let weekdayCodes = [1: "SU", 2: "MO", 3: "TU", 4: "WE", 5: "TH", 6: "FR", 7: "SA"]

    // MARK: Document

    /// A complete `VCALENDAR` document with CRLF line endings and folded lines.
    func document(events: [ICSEvent] = [], todos: [ICSTodo] = [], calendarName: String? = nil) -> String {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:\(productID)",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
        ]
        if let calendarName, !calendarName.isEmpty {
            lines.append("X-WR-CALNAME:" + Self.escape(calendarName))
        }
        lines += timeZoneLines(events: events, todos: todos)
        for event in events {
            lines += eventLines(event)
        }
        for todo in todos {
            lines += todoLines(todo)
        }
        lines.append("END:VCALENDAR")
        return lines.map(Self.fold).joined(separator: "\r\n") + "\r\n"
    }

    // MARK: Components

    func eventLines(_ event: ICSEvent) -> [String] {
        var lines = ["BEGIN:VEVENT"]
        lines.append("UID:" + Self.escape(event.uid))
        lines.append("DTSTAMP:" + ICSDateFormat.utcDateTime(stamp))
        lines.append(dateProperty("DTSTART", event.start, allDay: event.isAllDay, timeZone: event.timeZone))
        lines.append(dateProperty("DTEND", event.end, allDay: event.isAllDay, timeZone: event.timeZone))
        if let recurrenceID = event.recurrenceID {
            lines.append(dateProperty("RECURRENCE-ID", recurrenceID, allDay: event.isAllDay, timeZone: event.timeZone))
        }
        lines.append("SUMMARY:" + Self.escape(event.summary))
        if let location = event.location, !location.isEmpty {
            lines.append("LOCATION:" + Self.escape(location))
        }
        if let notes = event.notes, !notes.isEmpty {
            lines.append("DESCRIPTION:" + Self.escape(notes))
        }
        if let url = event.url {
            lines.append("URL:" + url.absoluteString)
        }
        if let recurrence = event.recurrence {
            lines.append("RRULE:" + rule(recurrence, allDay: event.isAllDay))
        }
        if !event.exceptionDates.isEmpty {
            lines.append(dateListProperty("EXDATE", event.exceptionDates, allDay: event.isAllDay, timeZone: event.timeZone))
        }
        for alarm in event.alarms {
            lines += alarmLines(alarm)
        }
        lines.append("END:VEVENT")
        return lines
    }

    func todoLines(_ todo: ICSTodo) -> [String] {
        var lines = ["BEGIN:VTODO"]
        lines.append("UID:" + Self.escape(todo.uid))
        lines.append("DTSTAMP:" + ICSDateFormat.utcDateTime(stamp))
        lines.append("SUMMARY:" + Self.escape(todo.summary))
        if let notes = todo.notes, !notes.isEmpty {
            lines.append("DESCRIPTION:" + Self.escape(notes))
        }
        if let due = todo.due {
            if todo.recurrence != nil {
                // RFC 5545 requires DTSTART when a VTODO recurs.
                lines.append(dateProperty("DTSTART", due, allDay: todo.dueIsAllDay, timeZone: todo.dueTimeZone))
            }
            lines.append(dateProperty("DUE", due, allDay: todo.dueIsAllDay, timeZone: todo.dueTimeZone))
        }
        if todo.priority > 0 {
            lines.append("PRIORITY:\(min(todo.priority, 9))")
        }
        lines.append("STATUS:" + (todo.isCompleted ? "COMPLETED" : "NEEDS-ACTION"))
        if todo.isCompleted, let completed = todo.completionDate {
            lines.append("COMPLETED:" + ICSDateFormat.utcDateTime(completed))
        }
        if let listName = todo.listName, !listName.isEmpty {
            lines.append("CATEGORIES:" + Self.escape(listName))
        }
        if let recurrence = todo.recurrence {
            lines.append("RRULE:" + rule(recurrence, allDay: todo.dueIsAllDay))
        }
        for alarm in todo.alarms {
            lines += alarmLines(alarm)
        }
        lines.append("END:VTODO")
        return lines
    }

    func alarmLines(_ alarm: ICSAlarm) -> [String] {
        var lines = ["BEGIN:VALARM", "ACTION:DISPLAY"]
        switch alarm.trigger {
        case .relative(let seconds):
            lines.append("TRIGGER:" + Self.duration(seconds))
        case .absolute(let date):
            lines.append("TRIGGER;VALUE=DATE-TIME:" + ICSDateFormat.utcDateTime(date))
        }
        lines.append("DESCRIPTION:" + Self.escape(alarm.description))
        lines.append("END:VALARM")
        return lines
    }

    // MARK: Properties

    func dateProperty(_ name: String, _ date: Date, allDay: Bool, timeZone: TimeZone?) -> String {
        dateListProperty(name, [date], allDay: allDay, timeZone: timeZone)
    }

    func dateListProperty(_ name: String, _ dates: [Date], allDay: Bool, timeZone: TimeZone?) -> String {
        if allDay {
            let values = dates.map { ICSDateFormat.date($0, in: floatingTimeZone) }
            return "\(name);VALUE=DATE:" + values.joined(separator: ",")
        }
        guard let timeZone else {
            let values = dates.map { ICSDateFormat.dateTime($0, in: floatingTimeZone) }
            return "\(name):" + values.joined(separator: ",")
        }
        if ICSDateFormat.isUTC(timeZone) {
            return "\(name):" + dates.map(ICSDateFormat.utcDateTime).joined(separator: ",")
        }
        let values = dates.map { ICSDateFormat.dateTime($0, in: timeZone) }
        return "\(name);TZID=\(timeZone.identifier):" + values.joined(separator: ",")
    }

    /// `RRULE` value, e.g. `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=10`.
    func rule(_ recurrence: ICSRecurrence, allDay: Bool) -> String {
        var parts = ["FREQ=" + recurrence.frequency.rawValue]
        if recurrence.interval > 1 {
            parts.append("INTERVAL=\(recurrence.interval)")
        }
        if let count = recurrence.count, count > 0 {
            parts.append("COUNT=\(count)")
        } else if let until = recurrence.until {
            let value = allDay ? ICSDateFormat.date(until, in: floatingTimeZone) : ICSDateFormat.utcDateTime(until)
            parts.append("UNTIL=" + value)
        }
        if !recurrence.daysOfWeek.isEmpty {
            let days = recurrence.daysOfWeek.compactMap { day -> String? in
                guard let code = Self.weekdayCodes[day.weekday] else { return nil }
                return day.ordinal == 0 ? code : "\(day.ordinal)\(code)"
            }
            parts.append("BYDAY=" + days.joined(separator: ","))
        }
        let numericParts: [(String, [Int])] = [
            ("BYMONTHDAY", recurrence.daysOfMonth),
            ("BYMONTH", recurrence.monthsOfYear),
            ("BYWEEKNO", recurrence.weeksOfYear),
            ("BYYEARDAY", recurrence.daysOfYear),
            ("BYSETPOS", recurrence.setPositions),
        ]
        for (name, values) in numericParts where !values.isEmpty {
            parts.append(name + "=" + values.map(String.init).joined(separator: ","))
        }
        if let weekStart = recurrence.weekStart, let code = Self.weekdayCodes[weekStart] {
            parts.append("WKST=" + code)
        }
        return parts.joined(separator: ";")
    }

    // MARK: Time zones

    func timeZoneLines(events: [ICSEvent], todos: [ICSTodo]) -> [String] {
        var zones: [String: TimeZone] = [:]
        var earliest: Date?
        var latest: Date?

        func include(_ zone: TimeZone?, _ dates: [Date?]) {
            guard let zone, !ICSDateFormat.isUTC(zone) else { return }
            zones[zone.identifier] = zone
            for case let date? in dates {
                earliest = min(earliest ?? date, date)
                latest = max(latest ?? date, date)
            }
        }

        for event in events where !event.isAllDay {
            include(event.timeZone, [event.start, event.end, event.recurrence?.until])
        }
        for todo in todos where !todo.dueIsAllDay {
            include(todo.dueTimeZone, [todo.due, todo.recurrence?.until])
        }
        guard !zones.isEmpty else { return [] }

        let calendar = ICSDateFormat.calendar(in: ICSDateFormat.utc)
        let start = calendar.date(byAdding: .year, value: -1, to: earliest ?? stamp) ?? stamp
        let proposedEnd = calendar.date(byAdding: .year, value: 2, to: latest ?? stamp) ?? stamp
        let maxEnd = calendar.date(byAdding: .year, value: 40, to: start) ?? proposedEnd
        let end = min(proposedEnd, maxEnd)

        return zones.keys.sorted().flatMap { identifier in
            Self.timeZoneComponent(zones[identifier] ?? .current, from: start, to: end)
        }
    }

    /// `VTIMEZONE` with explicit observances for every transition between `from` and `to`.
    static func timeZoneComponent(_ zone: TimeZone, from start: Date, to end: Date) -> [String] {
        var lines = ["BEGIN:VTIMEZONE", "TZID:\(zone.identifier)"]
        let initialOffset = zone.secondsFromGMT(for: start)
        let initialKind = zone.isDaylightSavingTime(for: start) ? "DAYLIGHT" : "STANDARD"
        lines += observance(
            kind: initialKind,
            localStart: "19700101T000000",
            from: initialOffset,
            to: initialOffset,
            name: zone.abbreviation(for: start)
        )

        var cursor = start
        var transitions = 0
        while let next = zone.nextDaylightSavingTimeTransition(after: cursor), next <= end, transitions < 120 {
            let before = zone.secondsFromGMT(for: next.addingTimeInterval(-1))
            let after = zone.secondsFromGMT(for: next)
            let local = next.addingTimeInterval(TimeInterval(before))
            lines += observance(
                kind: zone.isDaylightSavingTime(for: next) ? "DAYLIGHT" : "STANDARD",
                localStart: ICSDateFormat.dateTime(local, in: ICSDateFormat.utc),
                from: before,
                to: after,
                name: zone.abbreviation(for: next)
            )
            cursor = next
            transitions += 1
        }
        lines.append("END:VTIMEZONE")
        return lines
    }

    private static func observance(kind: String, localStart: String, from: Int, to: Int, name: String?) -> [String] {
        var lines = ["BEGIN:\(kind)", "DTSTART:\(localStart)"]
        lines.append("TZOFFSETFROM:" + offset(from))
        lines.append("TZOFFSETTO:" + offset(to))
        if let name, !name.isEmpty {
            lines.append("TZNAME:" + escape(name))
        }
        lines.append("END:\(kind)")
        return lines
    }

    /// UTC offset as `+HHMM` (or `+HHMMSS` when seconds are present).
    static func offset(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let total = abs(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        var text = sign + twoDigits(hours) + twoDigits(minutes)
        if rest > 0 {
            text += twoDigits(rest)
        }
        return text
    }

    // MARK: Text helpers

    /// Escapes TEXT values: backslash, semicolon, comma and line breaks.
    static func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "\\":
                result += "\\\\"
            case ";":
                result += "\\;"
            case ",":
                result += "\\,"
            case "\r\n", "\n", "\r":
                result += "\\n"
            default:
                result.append(character)
            }
        }
        return result
    }

    /// Folds a content line so that no physical line exceeds 75 octets (continuations start with a space).
    /// Multi-byte UTF-8 characters are never split.
    static func fold(_ line: String) -> String {
        let limit = 75
        guard line.utf8.count > limit else { return line }
        var result = ""
        var currentLength = 0
        for character in line {
            let length = character.utf8.count
            if currentLength + length > limit {
                result += "\r\n "
                currentLength = 1
            }
            result.append(character)
            currentLength += length
        }
        return result
    }

    /// RFC 5545 duration, e.g. `-PT15M`, `P1D`, `-P1DT12H`.
    static func duration(_ seconds: TimeInterval) -> String {
        var remaining = Int(abs(seconds).rounded())
        guard remaining > 0 else { return "PT0S" }
        let days = remaining / 86_400
        remaining %= 86_400
        let hours = remaining / 3600
        remaining %= 3600
        let minutes = remaining / 60
        let secs = remaining % 60

        var text = seconds < 0 ? "-P" : "P"
        if days > 0 {
            text += "\(days)D"
        }
        if hours > 0 || minutes > 0 || secs > 0 {
            text += "T"
            if hours > 0 {
                text += "\(hours)H"
            }
            if minutes > 0 {
                text += "\(minutes)M"
            }
            if secs > 0 {
                text += "\(secs)S"
            }
        }
        return text
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : String(value)
    }
}
