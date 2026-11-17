import Foundation
import os

/// Library-wide logger. Messages go to the unified log (subsystem `PremiumKit`) and the Xcode console.
/// `details` (JSON fragments) are public in DEBUG builds and private in release builds.
enum PremiumLog {
    enum Category: String {
        case paywall
        case fallback
        case purchase
        case localization
        case network
    }

    /// Set from `PremiumConfiguration.isLoggingEnabled`.
    static var isEnabled = true

    private static let subsystem = "PremiumKit"
    private static let reportedLock = NSLock()
    private static var reportedKeys: Set<String> = []

    static func debug(_ category: Category, _ message: String, details: String? = nil) {
        log(.debug, category, message, details: details)
    }

    static func info(_ category: Category, _ message: String, details: String? = nil) {
        log(.info, category, "ℹ️ \(message)", details: details)
    }

    static func warning(_ category: Category, _ message: String, details: String? = nil) {
        log(.default, category, "⚠️ \(message)", details: details)
    }

    static func error(_ category: Category, _ message: String, details: String? = nil) {
        log(.error, category, "❌ \(message)", details: details)
    }

    /// Logs a warning only the first time `key` is reported during the app session.
    static func warningOnce(_ category: Category, key: String, _ message: String) {
        guard isEnabled, markReported(key) else { return }
        warning(category, message)
    }

    private static func markReported(_ key: String) -> Bool {
        reportedLock.lock()
        defer { reportedLock.unlock() }
        return reportedKeys.insert(key).inserted
    }

    private static func log(_ type: OSLogType, _ category: Category, _ message: String, details: String?) {
        guard isEnabled else { return }

        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        let text = "[PremiumKit] \(message)"

        guard let details else {
            logger.log(level: type, "\(text, privacy: .public)")
            return
        }

        #if DEBUG
        logger.log(level: type, "\(text, privacy: .public)\n\(details, privacy: .public)")
        #else
        logger.log(level: type, "\(text, privacy: .public)\n\(details, privacy: .private)")
        #endif
    }
}
