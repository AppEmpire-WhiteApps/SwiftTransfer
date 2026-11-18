import SwiftUI

/// S4b: the sender scans the receiver's QR code, or picks a nearby device and types its code.
struct PeerScanView: View {
    let model: TransferFlowModel

    @State private var codeEntryPeer: DiscoveredPeer?
    @State private var showsCodeEntry = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openURL) private var openURL

    private var browser: PeerBrowser {
        model.browser
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: Spacing.xl) {
                        scanner
                            .frame(maxWidth: 420)
                        nearbySection
                    }
                } else {
                    scanner
                    nearbySection
                }
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
            .padding(.bottom, 72)
        }
        .overlay {
            if model.isConnecting {
                connectingOverlay
            }
        }
        .navigationTitle(Text("Send to iPhone or iPad"))
        .onAppear {
            browser.start()
        }
        .sheet(isPresented: $showsCodeEntry) {
            PeerCodeEntrySheet(peers: browser.peers, initialPeer: codeEntryPeer) { peer, code in
                showsCodeEntry = false
                model.connect(peer: peer, code: code)
            }
            .presentationDetents([.medium, .large])
        }
        .trackScreen("transfer_peer_scan")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Scan the QR code")
                .font(AppFont.title1)
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("On the other iPhone or iPad, open SwiftTransfer and choose Receive → From iPhone or iPad.")
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let message = model.connectMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColor.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.xs)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    private var scanner: some View {
        QRScannerView(isActive: !model.isConnecting && model.currentRoute == .peerScan) { value in
            guard !model.isConnecting else { return }
            if let payload = PeerQRPayload.decode(value) {
                model.connect(qrPayload: payload)
            } else {
                model.connectMessage = String(localized: "This QR code isn't from SwiftTransfer.")
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .shadow(color: AppColor.primary.opacity(0.15), radius: 20, y: 8)
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeader(title: "Nearby devices")
            if browser.state == .localNetworkDenied {
                localNetworkCard
            } else if browser.peers.isEmpty {
                HStack(spacing: Spacing.l) {
                    PulseRings()
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                    Text("Looking for devices with the receive screen open…")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(browser.peers) { peer in
                        Button {
                            codeEntryPeer = peer
                            showsCodeEntry = true
                        } label: {
                            PeerRow(peer: peer)
                        }
                        .buttonStyle(.plain)
                        if peer.id != browser.peers.last?.id {
                            Divider().overlay(AppColor.divider)
                        }
                    }
                }
                .cardStyle(padding: Spacing.s)
            }
            Button("Enter code") {
                codeEntryPeer = browser.peers.count == 1 ? browser.peers.first : nil
                showsCodeEntry = true
            }
            .buttonStyle(.secondary)
            .disabled(browser.peers.isEmpty)
        }
    }

    private var localNetworkCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Local network access is off")
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text("Turn on Local Network for SwiftTransfer in Settings to find nearby devices.")
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.secondary)
        }
        .cardStyle(background: AppColor.skyMist)
    }

    private var connectingOverlay: some View {
        ZStack {
            AppColor.background.opacity(0.85)
                .ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                ZStack {
                    PulseRings()
                        .frame(width: 160, height: 160)
                    IllustrationView(illustration: .connectSearching, height: 120, glow: false)
                }
                .accessibilityHidden(true)
                Text("Connecting securely…")
                    .font(AppFont.title2)
                    .foregroundStyle(AppColor.textPrimary)
                Button("Cancel") {
                    model.cancelConnecting()
                }
                .buttonStyle(.text)
            }
            .cardStyle(padding: Spacing.xxl)
            .pageMargins()
        }
        .accessibilityAddTraits(.isModal)
    }
}

private struct PeerRow: View {
    let peer: DiscoveredPeer

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: peer.model?.lowercased().contains("ipad") == true ? "ipad" : "iphone")
                .font(.title2)
                .foregroundStyle(AppColor.primary)
                .frame(width: 44, height: 44)
                .background(AppColor.skyMist, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.name)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                if let model = peer.model {
                    Text(model)
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(AppColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(Spacing.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Enter the code shown on this device"))
    }
}

/// Manual 6-digit code entry for a nearby device.
struct PeerCodeEntrySheet: View {
    let peers: [DiscoveredPeer]
    let onSubmit: (DiscoveredPeer, String) -> Void

    @State private var selectedPeerID: String?
    @State private var code = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(peers: [DiscoveredPeer], initialPeer: DiscoveredPeer?, onSubmit: @escaping (DiscoveredPeer, String) -> Void) {
        self.peers = peers
        self.onSubmit = onSubmit
        self._selectedPeerID = State(initialValue: initialPeer?.id ?? peers.first?.id)
    }

    private var selectedPeer: DiscoveredPeer? {
        peers.first { $0.id == selectedPeerID }
    }

    private var isValid: Bool {
        code.count == 6 && selectedPeer != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if peers.count > 1 {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("Device")
                                .font(AppFont.headline)
                            Picker("Device", selection: $selectedPeerID) {
                                ForEach(peers) { peer in
                                    Text(peer.name).tag(Optional(peer.id))
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                    } else if let peer = selectedPeer {
                        Label(peer.name, systemImage: "iphone")
                            .font(AppFont.headline)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("6-digit code from the other device")
                            .font(AppFont.callout)
                            .foregroundStyle(AppColor.textSecondary)
                        TextField("000000", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(AppFont.metric)
                            .multilineTextAlignment(.center)
                            .focused($isFocused)
                            .padding(Spacing.m)
                            .background(AppColor.skyMist, in: RoundedRectangle(cornerRadius: Radius.field))
                            .accessibilityLabel(Text("Code"))
                            .onChange(of: code) { _, newValue in
                                let digits = String(newValue.filter(\.isNumber).prefix(6))
                                if digits != newValue {
                                    code = digits
                                }
                            }
                    }
                    Button("Connect") {
                        if let peer = selectedPeer {
                            onSubmit(peer, code)
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(!isValid)
                }
                .pageMargins()
                .padding(.vertical, Spacing.l)
            }
            .screenBackground()
            .navigationTitle(Text("Enter code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .trackScreen("transfer_peer_code_entry")
    }
}

#Preview("Scan") {
    NavigationStack {
        PeerScanView(model: TransferFlowModel(start: .send(.iPhone)))
            .screenBackground()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}

#Preview("Code entry") {
    PeerCodeEntrySheet(peers: [], initialPeer: nil) { _, _ in }
        .environment(AppActivityContext())
}
