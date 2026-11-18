import EventKit
import Foundation

/// Converts between EventKit objects and the plain ICS value types.
enum EventKitMapping {
    // MARK: EventKit → ICS

    static func event(from event: EKEvent) -> ICSEvent {
        let uid = event.calendarItemExternalIdentifier ?? event.eventIdentifier ?? UUID().uuidString
        let start: Date = event.startDate
        var end: Date = event.endDate ?? start
        let isAllDay = event.isAllDay
        if isAllDay {
            // EventKit ends all-day events at 23:59:59 of the last day; iCalendar uses the next midnight.
            let calendar = Calendar.current
            let lastDay = calendar.startOfDay(for: max(end, start))
            end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? end
        }
        var result = ICSEvent(
            uid: uid,
            summary: event.title ?? "",
            start: isAllDay ? Calendar.current.startOfDay(for: start) : start,
            end: end,
            isAllDay: isAllDay,
            timeZone: isAllDay ? nil : event.timeZone
        )
        result.location = event.location
        result.notes = event.notes
        result.url = event.url
        if !event.isDetached {
            result.recurrence = event.recurrenceRules?.first.map(recurrence(from:))
        } else {
            result.recurrenceID = event.occurrenceDate
        }
        result.alarms = (event.alarms ?? []).compactMap(alarm(from:))
        return result
    }

    static func todo(from reminder: EKReminder, listName: String?) -> ICSTodo {
        var todo = ICSTodo(
            uid: reminder.calendarItemExternalIdentifier ?? reminder.calendarItemIdentifier,
            summary: reminder.title ?? ""
        )
        todo.notes = reminder.notes
        if let components = reminder.dueDateComponents {
            let hasTime = components.hour != nil
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = components.timeZone ?? .current
            if let due = calendar.date(from: components) {
                todo.due = due
                todo.dueIsAllDay = !hasTime
                todo.dueTimeZone = hasTime ? components.timeZone : nil
            }
        }
        todo.priority = reminder.priority
        todo.isCompleted = reminder.isCompleted
        todo.completionDate = reminder.completionDate
        todo.recurrence = reminder.recurrenceRules?.first.map(recurrence(from:))
        todo.alarms = (reminder.alarms ?? []).compactMap(alarm(from:))
        todo.listName = listName
        return todo
    }

    static func recurrence(from rule: EKRecurrenceRule) -> ICSRecurrence {
        let frequency: ICSFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: frequency = .daily
        }
        var result = ICSRecurrence(frequency: frequency, interval: max(rule.interval, 1))
        if let end = rule.recurrenceEnd {
            if end.occurrenceCount > 0 {
                result.count = end.occurrenceCount
            } else {
                result.until = end.endDate
            }
        }
        result.daysOfWeek = (rule.daysOfTheWeek ?? []).map {
            ICSWeekday(weekday: $0.dayOfTheWeek.rawValue, ordinal: $0.weekNumber)
        }
        result.daysOfMonth = (rule.daysOfTheMonth ?? []).map(\.intValue)
        result.monthsOfYear = (rule.monthsOfTheYear ?? []).map(\.intValue)
        result.weeksOfYear = (rule.weeksOfTheYear ?? []).map(\.intValue)
        result.daysOfYear = (rule.daysOfTheYear ?? []).map(\.intValue)
        result.setPositions = (rule.setPositions ?? []).map(\.intValue)
        if rule.firstDayOfTheWeek > 0 {
            result.weekStart = rule.firstDayOfTheWeek
        }
        return result
    }

    static func alarm(from alarm: EKAlarm) -> ICSAlarm? {
        if let date = alarm.absoluteDate {
            return ICSAlarm(trigger: .absolute(date))
        }
        return ICSAlarm(trigger: .relative(alarm.relativeOffset))
    }

    // MARK: ICS → EventKit

    static func rule(from recurrence: ICSRecurrence) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        switch recurrence.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        let days: [EKRecurrenceDayOfWeek] = recurrence.daysOfWeek.compactMap { day in
            guard let weekday = EKWeekday(rawValue: day.weekday) else { return nil }
            return day.ordinal == 0
                ? EKRecurrenceDayOfWeek(weekday)
                : EKRecurrenceDayOfWeek(weekday, weekNumber: day.ordinal)
        }
        var end: EKRecurrenceEnd?
        if let count = recurrence.count, count > 0 {
            end = EKRecurrenceEnd(occurrenceCount: count)
        } else if let until = recurrence.until {
            end = EKRecurrenceEnd(end: until)
        }
        func numbers(_ values: [Int]) -> [NSNumber]? {
            values.isEmpty ? nil : values.map { NSNumber(value: $0) }
        }
        // EventKit only accepts these parts for specific frequencies.
        let isYearly = recurrence.frequency == .yearly
        let allowsMonthDays = recurrence.frequency == .monthly
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: max(recurrence.interval, 1),
            daysOfTheWeek: days.isEmpty || recurrence.frequency == .daily ? nil : days,
            daysOfTheMonth: allowsMonthDays ? numbers(recurrence.daysOfMonth) : nil,
            monthsOfTheYear: isYearly ? numbers(recurrence.monthsOfYear) : nil,
            weeksOfTheYear: isYearly ? numbers(recurrence.weeksOfYear) : nil,
            daysOfTheYear: isYearly ? numbers(recurrence.daysOfYear) : nil,
            setPositions: days.isEmpty ? nil : numbers(recurrence.setPositions),
            end: end
        )
    }

    static func ekAlarm(from alarm: ICSAlarm) -> EKAlarm {
        switch alarm.trigger {
        case .relative(let offset):
            EKAlarm(relativeOffset: offset)
        case .absolute(let date):
            EKAlarm(absoluteDate: date)
        }
    }

    static func dueComponents(for todo: ICSTodo) -> DateComponents? {
        guard let due = todo.due else { return nil }
        let zone = todo.dueTimeZone ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        if todo.dueIsAllDay {
            var components = calendar.dateComponents([.year, .month, .day], from: due)
            components.calendar = calendar
            return components
        }
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        components.timeZone = todo.dueTimeZone
        return components
    }
}
