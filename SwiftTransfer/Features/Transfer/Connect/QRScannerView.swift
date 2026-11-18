import AVFoundation
import SwiftUI
import UIKit

/// Camera QR scanner with a rounded frame and a blue scan line (S4b).
/// Handles camera permission and shows a fallback in the Simulator.
struct QRScannerView: View {
    let isActive: Bool
    let onCode: (String) -> Void

    @State private var authorization = AVCaptureDevice.authorizationStatus(for: .video)
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(AppColor.primaryDeep)
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .task {
            if authorization == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                authorization = granted ? .authorized : .denied
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        #if targetEnvironment(simulator)
        fallback(
            systemImage: "camera",
            text: "The camera isn't available in the Simulator. Pick the device below and enter its code."
        )
        #else
        switch authorization {
        case .authorized:
            ZStack {
                CameraPreview(isActive: isActive, onCode: onCode)
                    .accessibilityLabel(Text("Camera viewfinder"))
                ScanFrame()
                    .padding(Spacing.xxxl)
                    .accessibilityHidden(true)
            }
        case .notDetermined:
            ProgressView()
                .tint(.white)
        default:
            VStack(spacing: Spacing.m) {
                fallback(
                    systemImage: "camera.fill",
                    text: "Allow camera access to scan the QR code, or enter the code instead."
                )
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.secondary)
                .frame(maxWidth: 240)
            }
            .padding(Spacing.l)
        }
        #endif
    }

    private func fallback(systemImage: String, text: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(AppColor.skyLight)
                .accessibilityHidden(true)
            Text(text)
                .font(AppFont.callout)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.xl)
    }
}

/// Rounded corner brackets with an animated scan line.
private struct ScanFrame: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lineAtBottom = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [side * 0.18, side * 0.64]))
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppGradient.primary)
                    .frame(height: 3)
                    .shadow(color: AppColor.sky, radius: 6)
                    .padding(.horizontal, Spacing.m)
                    .offset(y: reduceMotion ? 0 : (lineAtBottom ? side / 2 - Spacing.l : -side / 2 + Spacing.l))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                lineAtBottom = true
            }
        }
    }
}

/// AVCaptureSession preview reporting QR payloads.
private struct CameraPreview: UIViewRepresentable {
    let isActive: Bool
    let onCode: (String) -> Void

    func makeCoordinator() -> QRCaptureController {
        QRCaptureController()
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = context.coordinator.session
        view.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.onCode = onCode
        context.coordinator.setRunning(isActive)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onCode = onCode
        context.coordinator.setRunning(isActive)
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: QRCaptureController) {
        coordinator.setRunning(false)
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

/// Owns the capture session; configuration and start/stop run on a private serial queue.
final class QRCaptureController: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    /// Accessed on the main thread only.
    var onCode: ((String) -> Void)?
    private let queue = DispatchQueue(label: "swifttransfer.qr.session")
    private var isConfigured = false
    private var lastCode: String?
    private var lastCodeTime = Date.distantPast

    func setRunning(_ running: Bool) {
        queue.async { [self] in
            if running {
                configureIfNeeded()
                if isConfigured, !session.isRunning {
                    session.startRunning()
                }
            } else if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured,
              let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        if output.availableMetadataObjectTypes.contains(.qr) {
            output.metadataObjectTypes = [.qr]
        }
        isConfigured = true
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue
        else { return }
        // Delivered on the main queue (see setMetadataObjectsDelegate).
        if value == lastCode, Date().timeIntervalSince(lastCodeTime) < 3 {
            return
        }
        lastCode = value
        lastCodeTime = Date()
        onCode?(value)
    }
}

#Preview {
    QRScannerView(isActive: true) { _ in }
        .frame(height: 300)
        .padding()
}
