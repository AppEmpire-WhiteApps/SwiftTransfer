import CoreImage.CIFilterBuiltins
import SwiftUI

/// QR code (error correction H) in a white card with the app logo in the middle.
struct QRCodeView: View {
    let content: String
    var size: CGFloat = 220

    var body: some View {
        ZStack {
            if let image = QRCodeView.makeImage(from: content) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            }
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
                .frame(width: size * 0.22, height: size * 0.22)
                .overlay {
                    Illustration.appLogo.image
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                }
        }
        .frame(width: size, height: size)
        .padding(Spacing.l)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: AppColor.primary.opacity(0.14), radius: 16, x: 0, y: 12)
        .accessibilityLabel(Text("QR code"))
    }

    static func makeImage(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let colored = output.applyingFilter(
            "CIFalseColor",
            parameters: [
                "inputColor0": CIColor(red: 0.04, green: 0.24, blue: 0.57),
                "inputColor1": CIColor(red: 1, green: 1, blue: 1),
            ]
        )
        let scaled = colored.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRCodeView(content: "http://192.168.1.20:52000/s/abc")
        .padding()
        .screenBackground()
}
