import Foundation

/// Shared across conversations. Only accepted replies persist a trial use; reservations
/// are process-local so a failed, cancelled or interrupted request never spends a use.
final class AssistantTrialQuota {
    static let shared = AssistantTrialQuota()
    static let limit = 2

    private static let usageKey = "assistant.successfulFreeRequests.v1"
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var reservations: Set<UUID> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isExhausted: Bool {
        lock.withLock { successfulRequests >= Self.limit }
    }

    /// Reserves a free slot before any draft, thread or network mutation.
    func reserve() -> Reservation? {
        lock.withLock {
            guard successfulRequests + reservations.count < Self.limit else { return nil }
            let id = UUID()
            reservations.insert(id)
            return Reservation(id: id, quota: self)
        }
    }

    private var successfulRequests: Int {
        max(0, defaults.integer(forKey: Self.usageKey))
    }

    private func finish(_ id: UUID, succeeded: Bool) {
        lock.withLock {
            guard reservations.remove(id) != nil else { return }
            if succeeded {
                defaults.set(min(Self.limit, successfulRequests + 1), forKey: Self.usageKey)
            }
        }
    }

    /// Completion and release are idempotent, including late cancelled responses.
    final class Reservation {
        private let id: UUID
        private let quota: AssistantTrialQuota

        fileprivate init(id: UUID, quota: AssistantTrialQuota) {
            self.id = id
            self.quota = quota
        }

        func succeed() {
            quota.finish(id, succeeded: true)
        }

        func cancel() {
            quota.finish(id, succeeded: false)
        }

        deinit {
            cancel()
        }
    }
}
