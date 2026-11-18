import SwiftUI
import UIKit

/// "Prepare iPhone" checklist before a direct cable transfer with the Android phone's own app.
struct CablePrepView: View {
    @Environment(AppRouter.self) private var router
    @State private var batteryLevel: Float = -1
    @State private var batteryState: UIDevice.BatteryState = .unknown
    @State private var freeBytes: Int64?

    static let minimumBattery: Float = 0.5
    static let recommendedFreeBytes: Int64 = 1_000_000_000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                IllustrationView(illustration: .methodCable, height: 180, glow: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Prepare iPhone")
                        .font(AppFont.title1)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("A cable transfer is done by the Android phone's transfer app (e.g. Smart Switch on Samsung Galaxy). Check these before you connect.")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: Spacing.m) {
                    StatusRow(title: "Battery at least 50%", detail: batteryDetail, status: batteryStatus)
                    StatusRow(title: "Free space on iPhone", detail: freeSpaceDetail, status: freeSpaceStatus)
                    StatusRow(
                        title: "Download iCloud photos first",
                        detail: Text("Settings → Photos → Download and Keep Originals. Photos stored only in iCloud are not copied by cable."),
                        status: .warning
                    )
                    StatusRow(
                        title: "Have a USB-C cable or adapter",
                        detail: Text("USB-C to USB-C, or Lightning to USB-C, plus the adapter that came with the Android phone if needed."),
                        status: .pending
                    )
                    StatusRow(
                        title: "Tap “Trust” on iPhone",
                        detail: Text("When asked “Trust This Computer?”, tap Trust and enter your passcode."),
                        status: .pending
                    )
                }
                .cardStyle()

                VStack(spacing: Spacing.s) {
                    Button {
                        router.openGuide(.cableGalaxy)
                    } label: {
                        Label("Open the cable guide", systemImage: "book")
                    }
                    .buttonStyle(.primary)
                    Button {
                        router.askAssistant(draft: String(localized: "How do I transfer from iPhone to Android with a cable?"))
                    } label: {
                        Label("Ask the assistant", systemImage: "sparkles")
                    }
                    .buttonStyle(.secondary)
                }
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
            .pageMargins()
        }
        .screenBackground()
        .navigationTitle(Text("Cable to Android"))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("cable_prepare")
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            refresh()
        }
        .onDisappear {
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        freeBytes = ReceivedFilesStore.availableCapacity()
    }

    private var isCharging: Bool {
        batteryState == .charging || batteryState == .full
    }

    private var batteryStatus: CheckStatus {
        guard batteryLevel >= 0 else { return .pending }
        return batteryLevel >= Self.minimumBattery || isCharging ? .ok : .warning
    }

    private var batteryDetail: Text {
        guard batteryLevel >= 0 else {
            return Text("Battery level is not available.")
        }
        let percent = Text(Double(batteryLevel), format: .percent.precision(.fractionLength(0)))
        if batteryLevel >= Self.minimumBattery || isCharging {
            return Text("Now \(percent)")
        }
        return Text("Now \(percent). Connect a charger before you start.")
    }

    private var freeSpaceStatus: CheckStatus {
        guard let freeBytes else { return .pending }
        return freeBytes >= Self.recommendedFreeBytes ? .ok : .warning
    }

    private var freeSpaceDetail: Text {
        guard let freeBytes else {
            return Text("Checking…")
        }
        let free = Text(freeBytes, format: .byteCount(style: .file))
        if freeBytes >= Self.recommendedFreeBytes {
            return Text("\(free) free")
        }
        return Text("Only \(free) free. The transfer app may need some space for temporary files.")
    }
}

#Preview {
    NavigationStack {
        CablePrepView()
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}
