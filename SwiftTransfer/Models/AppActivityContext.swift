import Foundation
import Observation
import SwiftUI

/// Technical transfer state shared with the assistant (no personal data).
struct TransferContextInfo: Codable, Sendable, Equatable {
    var direction: TransferRole
    var method: TransferMethod
    var categories: [String: Int]
    var totalBytes: Int64
    /// e.g. "connecting", "selecting", "transferring", "completed", "failed".
    var state: String
    var lastError: String?

    enum CodingKeys: String, CodingKey {
        case direction
        case method
        case categories
        case totalBytes = "total_bytes"
        case state
        case lastError = "last_error"
    }
}

/// Result of the last connection check shared with the assistant.
struct ConnectionCheckContextInfo: Codable, Sendable, Equatable {
    var wifi: Bool
    var localNetworkPermission: Bool?
    var rttMs: Int?
    var throughputMbps: Int?
    var lowPower: Bool

    enum CodingKeys: String, CodingKey {
        case wifi
        case localNetworkPermission = "local_network_permission"
        case rttMs = "rtt_ms"
        case throughputMbps = "throughput_mbps"
        case lowPower = "low_power"
    }
}

/// App-wide technical state the assistant may include in its context.
@MainActor
@Observable
final class AppActivityContext {
    var currentScreen = "home"
    var transfer: TransferContextInfo?
    var connectionCheck: ConnectionCheckContextInfo?
}

extension View {
    /// Records the visible screen name (snake_case) for the assistant context.
    func trackScreen(_ name: String) -> some View {
        modifier(TrackScreenModifier(name: name))
    }
}

private struct TrackScreenModifier: ViewModifier {
    let name: String
    @Environment(AppActivityContext.self) private var activity

    func body(content: Content) -> some View {
        content.onAppear {
            activity.currentScreen = name
        }
    }
}
