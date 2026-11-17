import ApphudSDK
import Foundation

extension ApphudPaywall {
    var shouldShowFallback: Bool {
        guard let json, json["showFallback"] != nil,
              let data = try? JSONSerialization.data(withJSONObject: json)
        else { return false }

        do {
            return try JSONDecoder().decode(FallbackDirective.self, from: data).showFallback == true
        } catch {
            let report = JSONDiagnostics.describe(error, in: data)
            PremiumLog.warning(.paywall, "\(logLabel): showFallback ignored — \(report.message)")
            return false
        }
    }

    /// Decodes the paywall JSON; every failure is logged with its reason.
    var paywallResponse: ApphudPaywallResponse? {
        guard let json, !json.isEmpty else {
            logEmptyOrInvalidJSON()
            return nil
        }

        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: json)
        } catch {
            PremiumLog.error(.paywall, "\(logLabel): JSON could not be serialized — \(error.localizedDescription)")
            return nil
        }

        if let report = JSONDiagnostics.suspiciousCharacters(in: data) {
            PremiumLog.warning(.paywall, "\(logLabel): JSON \(report.message)", details: report.fragment)
        }

        do {
            return try JSONDecoder().decode(ApphudPaywallResponse.self, from: data)
        } catch {
            let report = JSONDiagnostics.describe(error, in: data)
            PremiumLog.error(
                .paywall,
                "\(logLabel): JSON does not match the paywall format — \(report.message)",
                details: report.fragment
            )
            return nil
        }
    }

    private var logLabel: String {
        "Apphud paywall \"\(identifier)\" (placement \(placementIdentifier ?? "—"))"
    }

    /// Apphud returns an empty dictionary both for an empty JSON and for one it could not parse,
    /// so the raw string is parsed again only to tell these cases apart and report the syntax error.
    private func logEmptyOrInvalidJSON() {
        guard let raw = rawJSONString,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            PremiumLog.warning(.paywall, "\(logLabel): JSON is empty in the Apphud dashboard")
            return
        }

        let data = Data(raw.utf8)
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            if object is [String: Any] {
                PremiumLog.warning(.paywall, "\(logLabel): JSON has no fields")
            } else {
                PremiumLog.error(.paywall, "\(logLabel): JSON must be an object { … }")
            }
        } catch {
            let report = JSONDiagnostics.describe(error, in: data)
            PremiumLog.error(.paywall, "\(logLabel): JSON is invalid — \(report.message)", details: report.fragment)
        }
    }

    /// ApphudSDK keeps the source string private; it is read only for diagnostics.
    private var rawJSONString: String? {
        Mirror(reflecting: self).children.first { $0.label == "jsonString" }?.value as? String
    }
}

private struct FallbackDirective: Decodable {
    let showFallback: Bool?
}
