import Foundation

/// Offline stand-in for SwiftUI previews of the assistant.
/// Replies are canned by keyword and include action buttons in structured mode.
struct MockLLMClient: LLMClienting {
    var delay: Duration = .milliseconds(1200)
    /// When set, every request fails with this error.
    var failure: LLMError?

    func complete(_ request: LLMRequest) async throws -> String {
        try await Task.sleep(for: delay)
        if let failure {
            throw failure
        }
        let question = request.messages.last { $0.role == .user }?.content ?? ""
        let reply = Self.reply(for: question)
        guard request.structured else {
            return reply.text
        }
        let object: [String: Any] = [
            "text": reply.text,
            "actions": reply.actions.map(\.rawValue),
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        return String(decoding: data, as: UTF8.self)
    }

    static func reply(for question: String) -> AssistantReply {
        let text = question.lowercased()
        if text.contains("whatsapp") {
            return AssistantReply(
                text: """
                This app **can't move WhatsApp chats** — iOS doesn't give apps access to them.

                Use WhatsApp's own transfer instead:
                1. Install WhatsApp on the new phone and sign in with the same number.
                2. Follow WhatsApp's **Move chats** instructions, or restore from a chat backup.
                3. Keep both phones charged and on the same Wi-Fi.

                Photos, contacts and calendars can still be moved with this app.
                """,
                actions: [.openGuideNotTransferable, .startSend]
            )
        }
        if text.contains("photo") || text.contains("video") {
            return AssistantReply(
                text: """
                Here's the quickest way to move photos to an Android phone:

                1. Connect both phones to the **same Wi-Fi** network.
                2. Tap **Send data** and choose **Android**.
                3. Scan the QR code with the Android camera — no app is needed there.
                4. Pick **Photos** and keep the screen on until the transfer finishes.

                Originals on your iPhone stay untouched.
                """,
                actions: [.startSend, .openGuideWifiGalaxy]
            )
        }
        if text.contains("found") || text.contains("find") || text.contains("see") {
            return AssistantReply(
                text: """
                If the second phone can't be found, check these:

                - Both phones are on the **same Wi-Fi** (not a guest network).
                - **Local Network** access is allowed for this app in Settings.
                - Mobile data and VPN are turned off for a moment.

                No shared Wi-Fi? Turn on the Android phone's **hotspot** and join it from the iPhone.
                """,
                actions: [.openConnectionCheck, .openGuideHotspot, .openSettingsPermissions]
            )
        }
        if text.contains("cable") || text.contains("wire") {
            return AssistantReply(
                text: """
                For a wired transfer you have two options:

                1. **Smart Switch** on the Android side (e.g. Samsung Galaxy) with a USB-C to Lightning cable.
                2. Export to a **USB drive** from this app and open it on the Android phone.

                The guide walks you through each step.
                """,
                actions: [.openGuideCableGalaxy, .openStorageExport]
            )
        }
        if text.contains("contact") {
            return AssistantReply(
                text: """
                Contacts arrive on Android as a **.vcf** file. To import it:

                1. Open the **Contacts** app on Android.
                2. Go to **Settings → Import** and choose the .vcf file.
                3. Pick the account to save them to, e.g. your Google account.
                """,
                actions: [.openGuideImportSamsung]
            )
        }
        if text.contains("can't") || text.contains("cannot") || text.contains("not") {
            return AssistantReply(
                text: """
                iOS doesn't let apps read some data, so it **can't be moved** by any third-party app:

                - Messages and call history
                - Apple Notes and voice memos
                - Passwords, Wi-Fi networks and installed apps

                The guide lists official alternatives for each of them.
                """,
                actions: [.openGuideNotTransferable]
            )
        }
        return AssistantReply(
            text: """
            I can help you move data between **iPhone and Android**, or save and restore it with an **external drive**.

            Tell me which phone you're moving to, and I'll walk you through it step by step.
            """,
            actions: [.startSend, .openConnectionCheck]
        )
    }
}
