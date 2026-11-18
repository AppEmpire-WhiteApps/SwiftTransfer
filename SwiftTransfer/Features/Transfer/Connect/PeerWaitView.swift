import SwiftUI

/// S4c: the receiving iPhone/iPad shows a QR code, the 6-digit code and its name.
struct PeerWaitView: View {
    let model: TransferFlowModel
    let onHowItWorks: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.s) {
                    Text("Ready to receive")
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("On the other iPhone or iPad, open SwiftTransfer, choose Send → iPhone or iPad and scan this code.")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: Spacing.xl) {
                        qrCard
                            .frame(maxWidth: 420)
                        deviceCard
                    }
                } else {
                    qrCard
                    deviceCard
                }
                Button("How does it work?", action: onHowItWorks)
                    .buttonStyle(.text)
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
            .padding(.bottom, 72)
        }
        .navigationTitle(Text("Receive from iPhone"))
        .trackScreen("transfer_peer_wait")
    }

    private var qrCard: some View {
        VStack(spacing: Spacing.l) {
            if let content = model.peerQRContent, model.phase == .waiting {
                QRCodeView(content: content, size: sizeClass == .regular ? 260 : 220)
                    .accessibilityLabel(Text("QR code for connecting"))
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 220)
                    .accessibilityLabel(Text("Starting…"))
            }
            if let code = model.peerCode {
                CodeBadge(code: code, caption: "Or choose this device in the list and enter the code")
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Spacing.xl)
    }

    private var deviceCard: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                PulseRings()
                    .frame(width: 180, height: 180)
                IllustrationView(illustration: .deviceIphone, height: 120, glow: false)
            }
            .frame(height: 190)
            .accessibilityHidden(true)
            Text(model.deviceName)
                .font(AppFont.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("Waiting for the other device…")
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
            Label("Encrypted connection. Nothing goes through the internet.", systemImage: "lock.fill")
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        PeerWaitView(model: TransferFlowModel(start: .receive(.iPhone))) {}
            .screenBackground()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}
