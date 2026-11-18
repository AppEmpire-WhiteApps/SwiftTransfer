import SwiftUI

/// Connection error (timeout, lost connection, wrong code, version mismatch) and the
/// local network permission screen (TZ §4.2.5).
struct TransferFailureView: View {
    let model: TransferFlowModel
    let onCheckConnection: () -> Void
    let onAskAssistant: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    private var failure: TransferFailure {
        model.failure ?? .connectionTimeout
    }

    private var illustration: Illustration {
        switch failure {
        case .localNetworkDenied: .permissionAccess
        case .insufficientSpace: .storageDrive
        default: .errorConnection
        }
    }

    private var canRetry: Bool {
        switch failure {
        case .versionMismatch, .nothingToSend: false
        default: true
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(illustration: illustration, height: 200)
                VStack(spacing: Spacing.s) {
                    Text(failure.title)
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(failure.message)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if failure == .connectionTimeout || failure == .connectionLost {
                    reasonsCard
                }
                actions
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .navigationTitle(Text("Connection"))
        .sensoryFeedback(.error, trigger: failure)
        .trackScreen(failure == .localNetworkDenied ? "transfer_local_network_denied" : "transfer_error")
    }

    private var reasonsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Common reasons")
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
            reason("wifi", "The devices are on different Wi-Fi networks")
            reason("personalhotspot", "Guest Wi-Fi blocks devices from seeing each other — use Personal Hotspot")
            reason("lock.shield", "A VPN or Private Relay is turned on")
            reason("hand.raised", "Local network access isn't allowed for this app")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func reason(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AppColor.primary)
        }
        .font(AppFont.callout)
        .foregroundStyle(AppColor.textSecondary)
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            if failure == .localNetworkDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.primary)
                Button("Try again") {
                    model.retryAfterFailure()
                }
                .buttonStyle(.secondary)
            } else {
                if canRetry {
                    Button("Retry") {
                        model.retryAfterFailure()
                    }
                    .buttonStyle(.primary)
                }
                Button("Check connection", action: onCheckConnection)
                    .buttonStyle(.secondary)
            }
            Button {
                onAskAssistant()
            } label: {
                Label("Ask the assistant", systemImage: "sparkles")
            }
            .buttonStyle(.text)
            if !canRetry {
                Button("Close", action: onClose)
                    .buttonStyle(.text)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TransferFailureView(model: TransferFlowModel(start: .send(.iPhone)), onCheckConnection: {}, onAskAssistant: {}, onClose: {})
            .screenBackground()
    }
    .environment(AppActivityContext())
}
