import Foundation
import UIKit
import UserNotifications

extension Illustration {
    /// PNG bytes of the app logo served to the Android page at `/assets/logo.png`.
    @MainActor
    static var appLogoPNGData: Data? {
        guard let image = UIImage(named: Illustration.appLogo.rawValue) else { return nil }
        let maxSide: CGFloat = 256
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        guard scale < 1 else { return image.pngData() }
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// Local notification "Transfer paused, return to the app" for iOS versions without
/// continued background processing (TZ §4.9).
enum TransferNotifications {
    private static let identifier = "swifttransfer.transfer.paused"

    /// Requests provisional authorization (no prompt) when a transfer starts.
    static func prepare() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .provisional]) { _, _ in }
    }

    static func schedulePausedReminder() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Transfer paused")
        content.body = String(localized: "Return to the app to continue the transfer.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 25, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    static func cancelPausedReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

extension TransferRecord {
    /// History entry for a finished transfer.
    convenience init(outcome: TransferOutcome) {
        var counts = outcome.counts
        if outcome.savedFiles > 0, counts[.files] == nil {
            counts[.files] = outcome.savedFiles
        }
        self.init(
            role: outcome.role,
            method: outcome.method,
            peerName: outcome.peerName,
            categoryCounts: counts,
            totalBytes: outcome.bytes,
            duration: outcome.duration,
            status: outcome.status,
            errorSummaries: outcome.failures.prefix(50).map { "\($0.path): \($0.reason)" },
            created: outcome.created
        )
    }
}
