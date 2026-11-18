import Foundation

/// Shared application configuration.
enum AppConfig {
    static let supportEmail = "order@carolinedorsey84.lat"
    static let legalName = "SwiftTransfer"
    static let appStoreID = "6827972328"

    static var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")
    }

    static var reviewURL: URL? {
        guard let appStoreURL else { return nil }
        var components = URLComponents(url: appStoreURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "action", value: "write-review")]
        return components?.url
    }

    static let llmBaseURL = URL(string: "https://llmapps.space")!
    /// Ask the model for a JSON reply with action buttons (§7.7); falls back to plain text when off.
    static let assistantStructuredReplies = true
    /// Enable only if the LLMApps key is registered with the image2text type (§7.8).
    static let assistantImagesEnabled = false

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
