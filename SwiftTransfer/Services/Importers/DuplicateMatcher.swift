import Foundation

/// Normalized identity of a contact for duplicate detection.
struct ContactFingerprint: Hashable, Sendable {
    var name: String
    var phones: Set<String>
    var emails: Set<String>

    init(name: String, phones: [String], emails: [String]) {
        self.name = Self.normalizeName(name)
        self.phones = Set(phones.map(Self.normalizePhone).filter { !$0.isEmpty })
        self.emails = Set(emails.map(Self.normalizeEmail).filter { !$0.isEmpty })
    }

    static func normalizeName(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Digits only; the last 10 digits so that `+7 912…` and `8 912…` match.
    static func normalizePhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isASCII && $0.isNumber }
        return String(digits.suffix(10))
    }

    static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Duplicate rule for contacts (TZ §4.4): same full name and at least one shared phone or email.
/// Contacts without any phone or email are duplicates when the names match and the existing
/// contact has no phone or email either.
struct ContactDuplicateMatcher: Sendable {
    private var byName: [String: [ContactFingerprint]] = [:]

    init(existing: [ContactFingerprint] = []) {
        for fingerprint in existing {
            insert(fingerprint)
        }
    }

    mutating func insert(_ fingerprint: ContactFingerprint) {
        guard !fingerprint.name.isEmpty else { return }
        byName[fingerprint.name, default: []].append(fingerprint)
    }

    func isDuplicate(_ candidate: ContactFingerprint) -> Bool {
        guard !candidate.name.isEmpty, let sameName = byName[candidate.name] else { return false }
        let candidateHasContacts = !candidate.phones.isEmpty || !candidate.emails.isEmpty
        return sameName.contains { existing in
            if !candidateHasContacts {
                return existing.phones.isEmpty && existing.emails.isEmpty
            }
            return !existing.phones.isDisjoint(with: candidate.phones)
                || !existing.emails.isDisjoint(with: candidate.emails)
        }
    }
}

/// Duplicate index for events (UID + start, or title + start) and reminders (title + due day).
struct CalendarDuplicateIndex: Sendable {
    private var keys: Set<String> = []

    init() {}

    static func uidKey(_ uid: String, start: Date) -> String {
        "uid|\(uid)|\(Int(start.timeIntervalSince1970))"
    }

    static func titleKey(_ title: String, start: Date?) -> String {
        let normalized = ContactFingerprint.normalizeName(title)
        let time = start.map { String(Int($0.timeIntervalSince1970)) } ?? "-"
        return "title|\(normalized)|\(time)"
    }

    mutating func insertEvent(uid: String?, title: String, start: Date) {
        if let uid, !uid.isEmpty {
            keys.insert(Self.uidKey(uid, start: start))
        }
        keys.insert(Self.titleKey(title, start: start))
    }

    func containsEvent(uid: String?, title: String, start: Date) -> Bool {
        if let uid, !uid.isEmpty, keys.contains(Self.uidKey(uid, start: start)) {
            return true
        }
        return keys.contains(Self.titleKey(title, start: start))
    }

    mutating func insertReminder(title: String, due: Date?) {
        keys.insert(Self.titleKey(title, start: due))
    }

    func containsReminder(title: String, due: Date?) -> Bool {
        keys.contains(Self.titleKey(title, start: due))
    }
}
