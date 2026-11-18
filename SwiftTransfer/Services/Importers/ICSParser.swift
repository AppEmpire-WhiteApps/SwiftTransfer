import Foundation

/// One unfolded content line: `NAME;PARAM=value:VALUE`.
struct ICSProperty: Sendable, Hashable {
    var name: String
    var parameters: [String: String]
    var value: String
}

/// Parses iCalendar (RFC 5545) text into `ICSEvent` / `ICSTodo` values.
/// Supports line unfolding, TEXT unescaping, TZID / UTC / floating / VALUE=DATE times,
/// DURATION, RRULE, EXDATE, RECURRENCE-ID and VALARM triggers.
struct ICSParser: Sendable {
    /// Zone for floating times and all-day dates.
    var floatingTimeZone = TimeZone.current

    func parse(data: Data) -> ICSCalendar {
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        return parse(text)
    }

    func parse(_ text: String) -> ICSCalendar {
        var calendar = ICSCalendar()
        var stack: [String] = []
        var componentProperties: [ICSProperty] = []
        var alarmProperties: [ICSProperty] = []
        var alarms: [ICSAlarm] = []

        for property in Self.contentLines(text) {
            switch property.name {
            case "BEGIN":
                let component = property.value.uppercased()
                stack.append(component)
                if component == "VEVENT" || component == "VTODO" {
                    componentProperties = []
                    alarms = []
                } else if component == "VALARM" {
                    alarmProperties = []
                }
            case "END":
                let component = property.value.uppercased()
                if let index = stack.lastIndex(of: component) {
                    stack.removeSubrange(index...)
                }
                switch component {
                case "VALARM":
                    if let alarm = makeAlarm(alarmProperties) {
                        alarms.append(alarm)
                    }
                case "VEVENT":
                    if let event = makeEvent(componentProperties, alarms: alarms) {
                        calendar.events.append(event)
                    }
                case "VTODO":
                    if let todo = makeTodo(componentProperties, alarms: alarms) {
                        calendar.todos.append(todo)
                    }
                default:
                    break
                }
            default:
                switch stack.last {
                case "VALARM":
                    alarmProperties.append(property)
                case "VEVENT", "VTODO":
                    componentProperties.append(property)
                case "VCALENDAR":
                    if property.name == "X-WR-CALNAME" {
                        calendar.name = Self.unescape(property.value)
                    }
                default:
                    break
                }
            }
        }
        return calendar
    }

    // MARK: Lines

    /// Unfolds lines (CRLF/LF followed by a space or tab) and splits them into properties.
    static func contentLines(_ text: String) -> [ICSProperty] {
        var logicalLines: [String] = []
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if let first = rawLine.first, first == " " || first == "\t", !logicalLines.isEmpty {
                logicalLines[logicalLines.count - 1] += rawLine.dropFirst()
            } else if !rawLine.isEmpty {
                logicalLines.append(String(rawLine))
            }
        }
        return logicalLines.compactMap(parseLine)
    }

    static func parseLine(_ line: String) -> ICSProperty? {
        var name = ""
        var parameters: [String: String] = [:]
        var current = ""
        var parameterName: String?
        var inQuotes = false
        var readingName = true
        var valueStart: String.Index?

        var index = line.startIndex
        scan: while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                inQuotes.toggle()
            } else if !inQuotes && (character == ";" || character == ":") {
                if readingName {
                    name = current
                    readingName = false
                } else if let parameterName {
                    parameters[parameterName.uppercased()] = current
                } else if !current.isEmpty {
                    parameters[current.uppercased()] = ""
                }
                current = ""
                parameterName = nil
                if character == ":" {
                    valueStart = line.index(after: index)
                    break scan
                }
            } else if !inQuotes && character == "=" && !readingName && parameterName == nil {
                parameterName = current
                current = ""
            } else {
                current.append(character)
            }
            index = line.index(after: index)
        }
        guard let valueStart, !name.isEmpty else { return nil }
        return ICSProperty(
            name: name.uppercased(),
            parameters: parameters,
            value: String(line[valueStart...])
        )
    }

    /// Reverses TEXT escaping (`\\`, `\;`, `\,`, `\n`).
    static func unescape(_ text: String) -> String {
        guard text.contains("\\") else { return text }
        var result = ""
        var escaping = false
        for character in text {
            if escaping {
                switch character {
                case "n", "N":
                    result.append("\n")
                default:
                    result.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    // MARK: Components

    private func makeEvent(_ properties: [ICSProperty], alarms: [ICSAlarm]) -> ICSEvent? {
        guard let startProperty = properties.first(named: "DTSTART"),
              let start = parseDate(startProperty) else { return nil }

        var end: Date
        if let endProperty = properties.first(named: "DTEND"), let parsedEnd = parseDate(endProperty) {
            end = parsedEnd.date
        } else if let duration = properties.first(named: "DURATION").flatMap({ Self.parseDuration($0.value) }) {
            end = start.date.addingTimeInterval(duration)
        } else if start.isDateOnly {
            end = ICSDateFormat.calendar(in: floatingTimeZone).date(byAdding: .day, value: 1, to: start.date) ?? start.date
        } else {
            end = start.date
        }
        if end < start.date {
            end = start.date
        }

        var event = ICSEvent(
            uid: properties.first(named: "UID").map { Self.unescape($0.value) } ?? UUID().uuidString,
            summary: properties.first(named: "SUMMARY").map { Self.unescape($0.value) } ?? "",
            start: start.date,
            end: end,
            isAllDay: start.isDateOnly,
            timeZone: start.timeZone
        )
        event.location = properties.first(named: "LOCATION").map { Self.unescape($0.value) }
        event.notes = properties.first(named: "DESCRIPTION").map { Self.unescape($0.value) }
        event.url = properties.first(named: "URL").flatMap { URL(string: $0.value.trimmingCharacters(in: .whitespaces)) }
        event.recurrence = properties.first(named: "RRULE").flatMap { parseRule($0.value) }
        event.recurrenceID = properties.first(named: "RECURRENCE-ID").flatMap { parseDate($0)?.date }
        event.exceptionDates = properties.filter { $0.name == "EXDATE" }.flatMap(parseDateList)
        event.alarms = alarms
        return event
    }

    private func makeTodo(_ properties: [ICSProperty], alarms: [ICSAlarm]) -> ICSTodo? {
        var todo = ICSTodo(
            uid: properties.first(named: "UID").map { Self.unescape($0.value) } ?? UUID().uuidString,
            summary: properties.first(named: "SUMMARY").map { Self.unescape($0.value) } ?? ""
        )
        todo.notes = properties.first(named: "DESCRIPTION").map { Self.unescape($0.value) }
        if let dueProperty = properties.first(named: "DUE") ?? properties.first(named: "DTSTART"),
           let due = parseDate(dueProperty) {
            todo.due = due.date
            todo.dueIsAllDay = due.isDateOnly
            todo.dueTimeZone = due.timeZone
        }
        todo.priority = properties.first(named: "PRIORITY").flatMap { Int($0.value.trimmingCharacters(in: .whitespaces)) } ?? 0
        let status = properties.first(named: "STATUS")?.value.uppercased()
        todo.completionDate = properties.first(named: "COMPLETED").flatMap { parseDate($0)?.date }
        todo.isCompleted = status == "COMPLETED" || todo.completionDate != nil
        todo.listName = properties.first(named: "CATEGORIES").flatMap { property in
            Self.splitList(property.value).first.map(Self.unescape)
        }
        todo.recurrence = properties.first(named: "RRULE").flatMap { parseRule($0.value) }
        todo.alarms = alarms
        return todo
    }

    private func makeAlarm(_ properties: [ICSProperty]) -> ICSAlarm? {
        guard let trigger = properties.first(named: "TRIGGER") else { return nil }
        let description = properties.first(named: "DESCRIPTION").map { Self.unescape($0.value) } ?? "Reminder"
        if trigger.parameters["VALUE"]?.uppercased() == "DATE-TIME" {
            guard let date = parseDate(trigger)?.date else { return nil }
            return ICSAlarm(trigger: .absolute(date), description: description)
        }
        guard let seconds = Self.parseDuration(trigger.value) else { return nil }
        return ICSAlarm(trigger: .relative(seconds), description: description)
    }

    // MARK: Dates

    struct ParsedDate {
        var date: Date
        var isDateOnly: Bool
        var timeZone: TimeZone?
    }

    func parseDate(_ property: ICSProperty) -> ParsedDate? {
        parseDateValue(property.value, parameters: property.parameters)
    }

    private func parseDateList(_ property: ICSProperty) -> [Date] {
        property.value.split(separator: ",").compactMap { value in
            parseDateValue(String(value), parameters: property.parameters)?.date
        }
    }

    func parseDateValue(_ rawValue: String, parameters: [String: String]) -> ParsedDate? {
        let value = rawValue.trimmingCharacters(in: .whitespaces)
        let digits = value.filter(\.isNumber)
        guard digits.count >= 8,
              let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.dropFirst(6).prefix(2)) else { return nil }

        let isDateOnly = parameters["VALUE"]?.uppercased() == "DATE" || !value.contains("T")
        if isDateOnly {
            let components = DateComponents(year: year, month: month, day: day)
            guard let date = ICSDateFormat.calendar(in: floatingTimeZone).date(from: components) else { return nil }
            return ParsedDate(date: date, isDateOnly: true, timeZone: nil)
        }

        let time = digits.dropFirst(8)
        let hour = Int(time.prefix(2)) ?? 0
        let minute = Int(time.dropFirst(2).prefix(2)) ?? 0
        let second = Int(time.dropFirst(4).prefix(2)) ?? 0
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)

        let zone: TimeZone?
        if value.hasSuffix("Z") || value.hasSuffix("z") {
            zone = ICSDateFormat.utc
        } else if let identifier = parameters["TZID"] {
            zone = Self.timeZone(forTZID: identifier) ?? floatingTimeZone
        } else {
            zone = nil
        }
        guard let date = ICSDateFormat.calendar(in: zone ?? floatingTimeZone).date(from: components) else { return nil }
        return ParsedDate(date: date, isDateOnly: false, timeZone: zone)
    }

    /// Resolves IANA identifiers, including prefixed forms like `/mozilla.org/20050126_1/Europe/Berlin`.
    static func timeZone(forTZID identifier: String) -> TimeZone? {
        let trimmed = identifier.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        if let zone = TimeZone(identifier: trimmed) {
            return zone
        }
        let components = trimmed.split(separator: "/")
        if components.count >= 2 {
            let candidate = components.suffix(2).joined(separator: "/")
            if let zone = TimeZone(identifier: candidate) {
                return zone
            }
        }
        return TimeZone(abbreviation: trimmed)
    }

    /// Parses an RFC 5545 duration such as `-PT15M`, `P1D` or `P1W`.
    static func parseDuration(_ rawValue: String) -> TimeInterval? {
        var value = Substring(rawValue.trimmingCharacters(in: .whitespaces).uppercased())
        var sign: Double = 1
        if value.hasPrefix("-") {
            sign = -1
            value = value.dropFirst()
        } else if value.hasPrefix("+") {
            value = value.dropFirst()
        }
        guard value.hasPrefix("P") else { return nil }
        value = value.dropFirst()

        var total: Double = 0
        var number = ""
        var inTime = false
        for character in value {
            if character.isNumber {
                number.append(character)
                continue
            }
            if character == "T" {
                inTime = true
                continue
            }
            guard let amount = Double(number) else { return nil }
            number = ""
            switch character {
            case "W": total += amount * 604_800
            case "D": total += amount * 86_400
            case "H": total += amount * 3600
            case "M": total += inTime ? amount * 60 : amount * 2_592_000
            case "S": total += amount
            default: return nil
            }
        }
        return sign * total
    }

    // MARK: Recurrence

    func parseRule(_ value: String) -> ICSRecurrence? {
        var parts: [String: String] = [:]
        for part in value.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            parts[pair[0].uppercased().trimmingCharacters(in: .whitespaces)] = String(pair[1])
        }
        guard let frequencyText = parts["FREQ"]?.uppercased(),
              let frequency = ICSFrequency(rawValue: frequencyText) else { return nil }

        var rule = ICSRecurrence(frequency: frequency)
        rule.interval = parts["INTERVAL"].flatMap { Int($0) }.map { max($0, 1) } ?? 1
        rule.count = parts["COUNT"].flatMap { Int($0) }
        rule.until = parts["UNTIL"].flatMap { parseDateValue($0, parameters: [:])?.date }
        rule.daysOfWeek = (parts["BYDAY"] ?? "").split(separator: ",").compactMap { Self.parseWeekday(String($0)) }
        rule.daysOfMonth = Self.integers(parts["BYMONTHDAY"])
        rule.monthsOfYear = Self.integers(parts["BYMONTH"])
        rule.weeksOfYear = Self.integers(parts["BYWEEKNO"])
        rule.daysOfYear = Self.integers(parts["BYYEARDAY"])
        rule.setPositions = Self.integers(parts["BYSETPOS"])
        rule.weekStart = parts["WKST"].flatMap { Self.weekdayNumber($0) }
        return rule
    }

    static func parseWeekday(_ text: String) -> ICSWeekday? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count >= 2 else { return nil }
        let code = String(trimmed.suffix(2))
        guard let weekday = weekdayNumber(code) else { return nil }
        let ordinalText = trimmed.dropLast(2)
        let ordinal = ordinalText.isEmpty ? 0 : (Int(ordinalText) ?? 0)
        return ICSWeekday(weekday: weekday, ordinal: ordinal)
    }

    static func weekdayNumber(_ code: String) -> Int? {
        ICSWriter.weekdayCodes.first { $0.value == code.uppercased() }?.key
    }

    private static func integers(_ text: String?) -> [Int] {
        (text ?? "").split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Splits a comma separated TEXT list, honoring escaped commas.
    static func splitList(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var escaping = false
        for character in text {
            if escaping {
                current.append("\\")
                current.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "," {
                items.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        items.append(current)
        return items.filter { !$0.isEmpty }
    }
}

private extension Array where Element == ICSProperty {
    func first(named name: String) -> ICSProperty? {
        first { $0.name == name }
    }
}
