#if DEBUG
    import PremiumKit
    import SwiftUI

    /// Explicit debug launch inspection of SDK-decoded models, without granting entitlements.
    struct PremiumDiagnosticsView: View {
        @State private var snapshots: [String] = []
        @State private var finished = false

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(snapshots, id: \.self) { snapshot in
                        Text(verbatim: snapshot)
                            .font(.footnote.monospaced())
                            .accessibilityIdentifier("premium.snapshot")
                    }
                    Text(finished ? "Catalog inspection complete" : "Loading catalog")
                        .accessibilityIdentifier("premium.inspection.status")
                }
                .padding(20)
            }
            .task {
                for id in [PremiumPaywallID.onboarding, .main, PremiumRoute.assistant.paywallID] {
                    await Premium.shared.loadPaywall(id)
                    await Task.yield()
                    guard let paywall = Premium.shared.paywall(for: id) else { continue }
                    let snapshot = [
                        id.rawValue,
                        paywall.title,
                        paywall.configuration.rawValue,
                        paywall.products.map(\.id).joined(separator: ","),
                    ].joined(separator: " | ")
                    snapshots.append(snapshot)
                }
                finished = true
            }
        }
    }
#endif
