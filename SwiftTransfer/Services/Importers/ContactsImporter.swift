import Contacts
import Foundation

/// Adds contacts from vCard files. Uses `CNSaveRequest.add` only; existing contacts are never changed.
final class ContactsImporter {
    struct Outcome {
        var imported = 0
        var skipped = 0
        var created: [String] = []
    }

    private let store = CNContactStore()
    private var matcher: ContactDuplicateMatcher?
    private static let saveBatchSize = 200

    init() {}

    func importVCard(at url: URL, policy: DuplicatePolicy) throws -> Outcome {
        let data = try Data(contentsOf: url)
        let contacts = try CNContactVCardSerialization.contacts(with: data)
        if policy == .skip && matcher == nil {
            matcher = try loadExistingMatcher()
        }

        var outcome = Outcome()
        var toSave: [CNMutableContact] = []
        for contact in contacts {
            let fingerprint = Self.fingerprint(of: contact)
            if policy == .skip, matcher?.isDuplicate(fingerprint) == true {
                outcome.skipped += 1
                continue
            }
            matcher?.insert(fingerprint)
            if let mutable = contact.mutableCopy() as? CNMutableContact {
                toSave.append(mutable)
            }
        }

        var start = 0
        while start < toSave.count {
            let batch = Array(toSave[start..<min(start + Self.saveBatchSize, toSave.count)])
            let request = CNSaveRequest()
            for contact in batch {
                request.add(contact, toContainerWithIdentifier: nil)
            }
            try store.execute(request)
            outcome.created += batch.map(\.identifier)
            outcome.imported += batch.count
            start += Self.saveBatchSize
        }
        return outcome
    }

    /// Deletes only the given contacts ("Undo import").
    func delete(identifiers: [String]) throws {
        guard !identifiers.isEmpty else { return }
        let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
        guard !contacts.isEmpty else { return }
        let request = CNSaveRequest()
        for contact in contacts {
            if let mutable = contact.mutableCopy() as? CNMutableContact {
                request.delete(mutable)
            }
        }
        try store.execute(request)
    }

    // MARK: Duplicates

    static var fingerprintKeys: [CNKeyDescriptor] {
        [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]
    }

    static func fingerprint(of contact: CNContact) -> ContactFingerprint {
        var name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        if name.isEmpty, contact.isKeyAvailable(CNContactOrganizationNameKey) {
            name = contact.organizationName
        }
        let phones = contact.isKeyAvailable(CNContactPhoneNumbersKey) ? contact.phoneNumbers.map { $0.value.stringValue } : []
        let emails = contact.isKeyAvailable(CNContactEmailAddressesKey) ? contact.emailAddresses.map { $0.value as String } : []
        return ContactFingerprint(name: name, phones: phones, emails: emails)
    }

    private func loadExistingMatcher() throws -> ContactDuplicateMatcher {
        let collector = FingerprintCollector()
        let request = CNContactFetchRequest(keysToFetch: Self.fingerprintKeys)
        request.unifyResults = true
        try store.enumerateContacts(with: request) { contact, _ in
            collector.add(Self.fingerprint(of: contact))
        }
        return ContactDuplicateMatcher(existing: collector.fingerprints)
    }
}

private final class FingerprintCollector: @unchecked Sendable {
    private(set) var fingerprints: [ContactFingerprint] = []

    func add(_ fingerprint: ContactFingerprint) {
        fingerprints.append(fingerprint)
    }
}
