import Foundation

/// One reminder list with its items, used for `reminders.txt`.
struct ReminderListText: Sendable, Hashable {
    var title: String
    var items: [ICSTodo]
}

/// Writes a human-readable checklist: lists as headings, `[ ]` / `[x]` checkboxes and dates.
struct RemindersTextWriter: Sendable {
    var timeZone = TimeZone.current
    var heading = String(localized: "Reminders")

    func text(for lists: [ReminderListText]) -> String {
        var lines = [heading, String(repeating: "=", count: max(heading.count, 3)), ""]
        for list in lists {
            lines.append("## " + list.title)
            if list.items.isEmpty {
                lines.append("")
                continue
            }
            for item in list.items {
                lines.append(line(for: item))
                if let notes = item.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    for noteLine in notes.split(whereSeparator: \.isNewline) {
                        lines.append("    " + noteLine)
                    }
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func line(for item: ICSTodo) -> String {
        var text = (item.isCompleted ? "[x] " : "[ ] ") + item.summary
        if let due = item.due {
            text += " — " + format(due, dateOnly: item.dueIsAllDay, zone: item.dueTimeZone)
        }
        if item.isCompleted, let completed = item.completionDate {
            text += " (✓ " + format(completed, dateOnly: false, zone: nil) + ")"
        }
        if item.priority > 0 && item.priority <= 4 {
            text += " !"
        }
        return text
    }

    /// Locale-neutral `yyyy-MM-dd` or `yyyy-MM-dd HH:mm`.
    func format(_ date: Date, dateOnly: Bool, zone: TimeZone?) -> String {
        let calendar = ICSDateFormat.calendar(in: zone ?? timeZone)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let day = String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        if dateOnly {
            return day
        }
        return day + String(format: " %02ld:%02ld", parts.hour ?? 0, parts.minute ?? 0)
    }
}
