import SwiftUI

/// S4d: confirmation of an incoming P2P transfer with categories, size and duplicate policy.
struct IncomingTransferView: View {
    let model: TransferFlowModel

    @State private var isAnswering = false

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(spacing: Spacing.xl) {
                IllustrationView(illustration: .transferDevices, height: 180, floating: true)
                VStack(spacing: Spacing.s) {
                    Text("\(model.peerName) wants to send you data")
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let manifest = model.incomingManifest {
                        Text("\(manifest.items.count) items · \(manifest.totalBytes.byteString)")
                            .font(AppFont.callout)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                if let manifest = model.incomingManifest {
                    VStack(spacing: 0) {
                        ForEach(manifest.summaries, id: \.category) { entry in
                            HStack(spacing: Spacing.m) {
                                entry.category.illustration.image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .accessibilityHidden(true)
                                Text(entry.category.title)
                                    .font(AppFont.headline)
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer(minLength: Spacing.s)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(entry.summary.itemCount)")
                                        .font(AppFont.headline)
                                        .foregroundStyle(AppColor.textPrimary)
                                    Text(entry.summary.byteCount.byteString)
                                        .font(AppFont.footnote)
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                            }
                            .padding(.vertical, Spacing.s)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .cardStyle()
                }
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("If something already exists on this device")
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Picker("Duplicates", selection: $model.duplicatePolicy) {
                        ForEach(DuplicatePolicy.allCases, id: \.self) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Nothing on this device is overwritten or deleted — data is only added.")
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                VStack(spacing: Spacing.m) {
                    Button("Accept") {
                        isAnswering = true
                        model.answerIncoming(accept: true)
                    }
                    .buttonStyle(.primary(isLoading: isAnswering))
                    Button("Decline") {
                        isAnswering = true
                        model.answerIncoming(accept: false)
                    }
                    .buttonStyle(.secondary)
                }
                .disabled(isAnswering)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .pageMargins()
            .padding(.vertical, Spacing.l)
        }
        .navigationTitle(Text("Incoming transfer"))
        .trackScreen("transfer_incoming")
    }
}

#Preview {
    NavigationStack {
        IncomingTransferView(model: TransferFlowModel(start: .receive(.iPhone)))
            .screenBackground()
    }
    .environment(AppActivityContext())
}
