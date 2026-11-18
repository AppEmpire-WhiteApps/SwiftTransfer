import Foundation

/// Loads and renders the bundled web receiver page (Resources/WebReceiver, flattened into the bundle root).
enum WebReceiverResources {
    static let supportedLanguages = ["en", "ru", "uk", "cs", "pl", "de", "fr", "es", "it", "pt", "tr", "ko"]

    /// Static assets served under /assets/ (no personal data inside).
    static func asset(named name: String, bundle: Bundle = .main) -> Data? {
        let allowed = ["webreceiver_style.css", "webreceiver_app.js"]
        guard allowed.contains(name) else { return nil }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        guard let url = bundle.url(forResource: base, withExtension: ext) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Picks the best supported language from an Accept-Language header.
    static func negotiateLanguage(acceptLanguage: String?, available: [String] = supportedLanguages) -> String {
        guard let acceptLanguage, !acceptLanguage.isEmpty else { return "en" }
        var candidates: [(code: String, quality: Double, order: Int)] = []
        for (order, rawItem) in acceptLanguage.split(separator: ",").enumerated() {
            let parts = rawItem.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let tag = parts.first, !tag.isEmpty else { continue }
            var quality = 1.0
            for parameter in parts.dropFirst() where parameter.hasPrefix("q=") {
                quality = Double(parameter.dropFirst(2)) ?? 0
            }
            let primary = tag.split(separator: "-").first.map { $0.lowercased() } ?? tag.lowercased()
            candidates.append((primary, quality, order))
        }
        let sorted = candidates
            .filter { $0.quality > 0 }
            .sorted { $0.quality == $1.quality ? $0.order < $1.order : $0.quality > $1.quality }
        return sorted.first { available.contains($0.code) }?.code ?? "en"
    }

    /// English dictionary with the requested language merged on top.
    static func dictionary(for language: String, bundle: Bundle = .main) -> [String: String] {
        var result = loadDictionary("en", bundle: bundle)
        if language != "en" {
            for (key, value) in loadDictionary(language, bundle: bundle) {
                result[key] = value
            }
        }
        return result
    }

    private static func loadDictionary(_ language: String, bundle: Bundle) -> [String: String] {
        guard let url = bundle.url(forResource: "webreceiver_i18n_\(language)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return object.compactMapValues { $0 as? String }
    }

    /// Renders the single-page template with language, strings and page configuration.
    static func renderPage(
        language: String,
        config: [String: Any],
        bundle: Bundle = .main
    ) -> Data {
        let strings = dictionary(for: language, bundle: bundle)
        let stringsJSON = scriptSafeJSON(strings)
        let configJSON = scriptSafeJSON(config)
        guard let url = bundle.url(forResource: "webreceiver_index", withExtension: "html"),
              let template = try? String(contentsOf: url, encoding: .utf8)
        else {
            return Data(fallbackPage(language: language, configJSON: configJSON).utf8)
        }
        let html = template
            .replacingOccurrences(of: "{{LANG}}", with: language)
            .replacingOccurrences(of: "{{I18N_JSON}}", with: stringsJSON)
            .replacingOccurrences(of: "{{CONFIG_JSON}}", with: configJSON)
        return Data(html.utf8)
    }

    /// JSON that can be embedded inside a <script> element.
    static func scriptSafeJSON(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
            .replacingOccurrences(of: "</", with: "<\\/")
            .replacingOccurrences(of: "<!--", with: "<\\!--")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    /// Minimal page used if the bundled template is missing.
    private static func fallbackPage(language: String, configJSON: String) -> String {
        """
        <!doctype html><html lang="\(language)"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1"><title>Data transfer</title></head>
        <body style="font-family: system-ui, sans-serif; background: #F6F9FE; color: #0E1A2B; padding: 24px">
        <h1>Data transfer</h1><p id="s">Loading…</p>
        <script>var c = \(configJSON);
        if (c.base) { fetch(c.base + '/api/manifest').then(function (r) { return r.json(); }).then(function (m) {
        var s = document.getElementById('s'); s.textContent = '';
        (m.categories || []).forEach(function (cat) { (cat.files || []).forEach(function (f) {
        var a = document.createElement('a'); a.href = f.url; a.textContent = f.name; a.style.display = 'block';
        s.appendChild(a); }); }); }).catch(function () {}); }</script></body></html>
        """
    }
}
