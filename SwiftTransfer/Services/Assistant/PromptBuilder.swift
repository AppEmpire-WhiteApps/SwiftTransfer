import Foundation

/// One turn of conversation history.
struct ChatTurn: Sendable, Equatable {
    var role: LLMMessage.Role
    var content: String
}

/// Builds the system prompt and the message list for the LLM (TZ §7.4, §7.9).
enum PromptBuilder {
    static let maxHistoryMessages = 20
    static let maxHistoryCharacters = 24_000

    static let systemTemplate = """
    You are a friendly transfer assistant built into an iOS app.
    The app moves data between iPhone and Android (including Samsung Galaxy), and supports external drives.

    App capabilities:
    - Wi-Fi transfer to Android via the receiver's web browser (QR code, no app needed on Android).
    - Android -> iPhone upload via browser.
    - Export to an external USB drive (cable/adapter) and restore from it.
    - Step-by-step guides for wired transfer using Smart Switch on the Galaxy side.
    - Data: contacts (.vcf), calendar (.ics), reminders (.ics + .txt), photos and videos (original or compatible JPEG/H.264), files from the Files app.
    - Original data on the old device is never modified or deleted.
    - Contacts are transferred; the notes field inside contact cards is not included.
    - Connection check: Wi-Fi, local network permission, speed test, battery, free space.

    Not possible on iOS for third-party apps: SMS/iMessage, call history, Apple Notes, voice memos, passwords/keychain,
    Wi-Fi networks, installed apps and their data, DRM music, system settings, wallpapers, alarms.
    For these, suggest official alternatives (e.g. WhatsApp's own chat transfer, Google account sync,
    exporting passwords on a computer) and say clearly the app cannot do it.

    Rules:
    - Reply in {{LANGUAGE}} (the user's interface language) unless the user writes in another language.
    - Be concise: short paragraphs, numbered steps for instructions, max ~180 words unless asked for details.
    - Use only Markdown: **bold**, numbered and bulleted lists. No tables, no code blocks, no images.
    - Never ask for or repeat personal data (contact names, phone numbers, photos). Never invent features.
    - Describe only the transfer routes listed above. Refer to the product as "the app", not by a product name.
    - If unsure, recommend running "Connection check" or opening the relevant guide.
    - Off-topic questions: answer briefly and politely steer back to device transfer and setup.

    Current app context (technical, may be empty):
    {{CONTEXT_JSON}}
    """

    /// The system prompt with the language name and context JSON substituted.
    /// Pass a nil context when the user turned off "Send technical context".
    static func systemPrompt(languageName: String, context: AssistantContext?) -> String {
        systemTemplate
            .replacingOccurrences(of: "{{LANGUAGE}}", with: languageName)
            .replacingOccurrences(of: "{{CONTEXT_JSON}}", with: contextJSON(context))
    }

    /// Compact JSON of the technical context, or `{}` when there is none.
    static func contextJSON(_ context: AssistantContext?) -> String {
        guard let context else {
            return "{}"
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(context) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// System prompt followed by the trimmed history.
    static func messages(systemPrompt: String, history: [ChatTurn]) -> [LLMMessage] {
        [LLMMessage(role: .system, content: systemPrompt)]
            + trimmedHistory(history).map { LLMMessage(role: $0.role, content: $0.content) }
    }

    /// The last 20 turns, further trimmed from the start so the total stays within ~24 000 characters.
    /// The newest turn is always kept.
    static func trimmedHistory(_ history: [ChatTurn]) -> [ChatTurn] {
        let recent = history.suffix(maxHistoryMessages)
        var kept: [ChatTurn] = []
        var total = 0
        for turn in recent.reversed() {
            let length = turn.content.count
            if !kept.isEmpty, total + length > maxHistoryCharacters {
                break
            }
            kept.append(turn)
            total += length
        }
        return kept.reversed()
    }

    /// English name of the interface language for `{{LANGUAGE}}`, e.g. "Russian".
    static func languageName(forCode code: String) -> String {
        let english = Locale(identifier: "en")
        if let name = english.localizedString(forIdentifier: code) {
            return name
        }
        return english.localizedString(forLanguageCode: code) ?? "English"
    }

    /// The language code the UI is currently shown in, e.g. "ru" or "pt-BR".
    static var interfaceLanguageCode: String {
        Bundle.main.preferredLocalizations.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
    }
}
