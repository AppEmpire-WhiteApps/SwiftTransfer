import Foundation

/// Assistant request failures and their user-facing messages (TZ §7.10).
/// Raw values are persisted on failed chat messages, so keep them stable.
enum LLMError: String, Error, Sendable, CaseIterable {
    /// No internet connection.
    case offline
    /// The backend host can't be reached, e.g. connected to a hotspot without internet.
    case unreachable
    /// 401/403 twice in a row: most likely a wrong device clock.
    case unauthorized
    /// 429.
    case busy
    /// 5xx, timeout or an unreadable response.
    case server
    /// The model returned nothing usable.
    case emptyReply
    /// The build has no LLMApps key.
    case notConfigured

    /// Errors worth one automatic retry after a short delay.
    var isTransient: Bool {
        switch self {
        case .server, .unreachable: true
        default: false
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .offline:
            "No internet connection. The assistant needs the internet; data transfer works without it."
        case .unreachable:
            "Couldn't reach the assistant. If you're connected to the other phone's Wi-Fi or hotspot, the internet may be unavailable during the transfer."
        case .unauthorized:
            "Check the date and time on your device (Settings → General → Date & Time → Set Automatically)."
        case .busy:
            "The assistant is busy right now. Please try again in a minute."
        case .server:
            "Couldn't get a reply. Please try again."
        case .emptyReply:
            "The assistant couldn't answer. Try rephrasing your question."
        case .notConfigured:
            "The assistant will be available soon."
        }
    }
}
