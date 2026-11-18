import SwiftUI

/// S4a: QR code, link and code for the Android browser (download and upload modes).
struct WebConnectView: View {
    let model: TransferFlowModel
    let onHowItWorks: () -> Void
    let onHotspotGuide: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openURL) private var openURL

    private var isUpload: Bool {
        model.webMode == .upload
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                header
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: Spacing.xl) {
                        qrCard
                            .frame(maxWidth: 420)
                        VStack(spacing: Spacing.l) {
                            waitingCard
                            hotspotCard
                        }
                    }
                } else {
                    qrCard
                    waitingCard
                    hotspotCard
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
        .navigationTitle(isUpload ? Text("Receive from Android") : Text("Send to Android"))
        .trackScreen(isUpload ? "transfer_web_upload_connect" : "transfer_web_connect")
    }

    private var header: some View {
        VStack(spacing: Spacing.s) {
            Text("Scan with the Android phone")
                .font(AppFont.title1)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(isUpload
                ? "Open the Android camera and point it at the QR code. A page opens where you can choose photos, videos, contacts and files to send to this iPhone."
                : "Open the Android camera and point it at the QR code. A page with your data opens in the browser — no app needed.")
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var qrCard: some View {
        VStack(spacing: Spacing.l) {
            if let endpoint = model.webEndpoint, let url = endpoint.sessionURL {
                QRCodeView(content: url, size: sizeClass == .regular ? 260 : 220)
                    .accessibilityLabel(Text("QR code with the transfer link"))
                VStack(spacing: Spacing.xs) {
                    Text("Or type this address in the browser")
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                    Text(endpoint.rootURL ?? url)
                        .font(AppFont.headline.monospaced())
                        .foregroundStyle(AppColor.primaryDeep)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                CodeBadge(code: endpoint.code, caption: "and enter the code")
            } else if model.webEndpoint != nil {
                noNetworkContent
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 220)
                    .accessibilityLabel(Text("Starting…"))
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Spacing.xl)
    }

    private var noNetworkContent: some View {
        VStack(spacing: Spacing.m) {
            IllustrationView(illustration: .connectHotspot, height: 140)
            Text("Connect to Wi-Fi")
                .font(AppFont.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("This iPhone isn't on a Wi-Fi network. Join the same Wi-Fi as the Android phone, or turn on Personal Hotspot and connect the Android phone to it.")
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var waitingCard: some View {
        HStack(spacing: Spacing.l) {
            ZStack {
                PulseRings()
                    .frame(width: 72, height: 72)
                Illustration.deviceAndroid.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }
            .frame(width: 80, height: 80)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Waiting for connection…")
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text("You'll be asked to allow the Android phone when it opens the page.")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private var hotspotCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .top, spacing: Spacing.m) {
                Illustration.connectHotspot.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("No shared Wi-Fi?")
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Turn on Personal Hotspot on this iPhone and connect the Android phone to it. Mobile data isn't used for the transfer.")
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: Spacing.m) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.secondary)
                Button("Learn more", action: onHotspotGuide)
                    .buttonStyle(.text)
            }
        }
        .cardStyle(background: AppColor.skyMist)
    }
}

/// Large 6-digit code "123 456".
struct CodeBadge: View {
    let code: String
    var caption: LocalizedStringKey = "Code"

    private var spaced: String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(caption)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)
            Text(spaced)
                .font(AppFont.metric)
                .foregroundStyle(AppColor.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.s)
                .background(AppColor.skyMist, in: RoundedRectangle(cornerRadius: Radius.field))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Code \(code.map(String.init).joined(separator: " "))"))
    }
}

#Preview("Web connect") {
    NavigationStack {
        WebConnectView(model: TransferFlowModel(start: .send(.android)), onHowItWorks: {}, onHotspotGuide: {})
            .screenBackground()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}

#Preview("Code badge") {
    CodeBadge(code: "042137")
        .padding()
}
