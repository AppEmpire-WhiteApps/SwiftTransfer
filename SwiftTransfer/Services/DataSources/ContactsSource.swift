import Contacts
import Foundation

/// A contacts account/container (iCloud, Gmail, On My iPhone…).
struct ContactContainerInfo: Identifiable, Hashable, Sendable {
    enum Kind: Sendable, Hashable {
        case local
        case exchange
        case cardDAV
        case other
    }

    let id: String
    let name: String
    let kind: Kind
    let contactCount: Int
}

/// Read-only access to Contacts. Has no write methods (TZ §4.10).
actor ContactsSource {
    static let batchSize = 500

    private let store = CNContactStore()

    init() {}

    func containers() throws -> [ContactContainerInfo] {
        let containers = try store.containers(matching: nil)
        return containers.map { container in
            let predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            let keys = [CNContactIdentifierKey as CNKeyDescriptor]
            let count = (try? store.unifiedContacts(matching: predicate, keysToFetch: keys).count) ?? 0
            return ContactContainerInfo(
                id: container.identifier,
                name: Self.displayName(of: container),
                kind: Self.kind(of: container.type),
                contactCount: count
            )
        }
        .sorted { $0.contactCount > $1.contactCount }
    }

    /// Number of unique contacts in the given containers (nil = all).
    func count(containerIDs: Set<String>?) throws -> Int {
        let counter = UniqueContactCounter()
        try enumerate(containerIDs: containerIDs, keys: [CNContactIdentifierKey as CNKeyDescriptor]) { contact in
            counter.insert(contact.identifier)
        }
        return counter.count
    }

    /// Writes all contacts of the containers into one `.vcf` file, serializing in batches of 500
    /// so memory stays flat. Returns the number of exported contacts.
    func writeVCard(to url: URL, containerIDs: Set<String>?) throws -> Int {
        let writer = try VCardBatchWriter(url: url, batchSize: Self.batchSize)
        defer { writer.close() }
        try enumerate(containerIDs: containerIDs, keys: VCardExporter.keysToFetch) { contact in
            try writer.add(contact)
        }
        try writer.flush()
        return writer.exported
    }

    // MARK: Private

    private func enumerate(
        containerIDs: Set<String>?,
        keys: [CNKeyDescriptor],
        _ body: @escaping @Sendable (CNContact) throws -> Void
    ) throws {
        let predicates: [NSPredicate?]
        if let containerIDs {
            predicates = containerIDs.sorted().map { CNContact.predicateForContactsInContainer(withIdentifier: $0) }
        } else {
            predicates = [nil]
        }
        let failure = ErrorBox()
        for predicate in predicates {
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.predicate = predicate
            request.unifyResults = true
            try store.enumerateContacts(with: request) { contact, stop in
                do {
                    try body(contact)
                } catch {
                    failure.error = error
                    stop.pointee = true
                }
            }
            if let error = failure.error {
                throw error
            }
        }
    }

    private static func kind(of type: CNContainerType) -> ContactContainerInfo.Kind {
        switch type {
        case .local: .local
        case .exchange: .exchange
        case .cardDAV: .cardDAV
        default: .other
        }
    }

    private static func displayName(of container: CNContainer) -> String {
        let name = container.name.trimmingCharacters(in: .whitespaces)
        switch container.type {
        case .local:
            return String(localized: "On My iPhone")
        case .cardDAV where name.isEmpty || name == "Card":
            return "iCloud"
        default:
            return name.isEmpty ? String(localized: "Other account") : name
        }
    }
}

/// Collects contacts and appends them to a `.vcf` file in batches. Used sequentially by one enumeration.
private final class VCardBatchWriter: @unchecked Sendable {
    private let handle: FileHandle
    private let batchSize: Int
    private var batch: [CNContact] = []
    private var seen = Set<String>()
    private(set) var exported = 0

    init(url: URL, batchSize: Int) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        self.batchSize = batchSize
    }

    func add(_ contact: CNContact) throws {
        guard seen.insert(contact.identifier).inserted else { return }
        batch.append(contact)
        if batch.count >= batchSize {
            try flush()
        }
    }

    func flush() throws {
        guard !batch.isEmpty else { return }
        let data = try VCardExporter.data(for: batch)
        try handle.write(contentsOf: data)
        exported += batch.count
        batch.removeAll(keepingCapacity: true)
    }

    func close() {
        try? handle.close()
    }
}

/// Counts unique identifiers during one sequential enumeration.
private final class UniqueContactCounter: @unchecked Sendable {
    private var identifiers = Set<String>()

    var count: Int { identifiers.count }

    func insert(_ identifier: String) {
        identifiers.insert(identifier)
    }
}

/// Carries an error out of a synchronous enumeration block.
final class ErrorBox: @unchecked Sendable {
    var error: Error?
}
