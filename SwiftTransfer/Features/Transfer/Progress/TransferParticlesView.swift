import SwiftUI

/// Two devices with data particles flying along an arc (TimelineView + Canvas, ≤ 30 fps).
/// Static when Reduce Motion is on or the transfer is paused.
struct TransferParticlesView: View {
    var isAnimating = true
    var height: CGFloat = 180

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particleCount = 9
    private let cycle: Double = 2.4

    var body: some View {
        ZStack {
            IllustrationView(illustration: .transferDevices, height: height)
            if isAnimating && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    Canvas { canvas, size in
                        draw(in: &canvas, size: size, time: context.date.timeIntervalSinceReferenceDate)
                    }
                }
                .frame(height: height)
                .allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let start = CGPoint(x: size.width * 0.28, y: size.height * 0.45)
        let end = CGPoint(x: size.width * 0.72, y: size.height * 0.45)
        let control = CGPoint(x: size.width * 0.5, y: size.height * 0.02)
        for index in 0..<particleCount {
            let phase = (time / cycle + Double(index) / Double(particleCount)).truncatingRemainder(dividingBy: 1)
            let t = CGFloat(phase)
            let point = CGPoint(
                x: pow(1 - t, 2) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x,
                y: pow(1 - t, 2) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y
            )
            let fade = sin(Double.pi * phase)
            let radius = 3 + 3 * CGFloat(fade)
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            canvas.opacity = fade
            canvas.fill(Path(ellipseIn: rect.insetBy(dx: -radius, dy: -radius)), with: .color(AppColor.sky.opacity(0.25)))
            canvas.fill(Path(ellipseIn: rect), with: .color(index.isMultiple(of: 2) ? AppColor.primary : AppColor.sky))
        }
    }
}

#Preview {
    TransferParticlesView()
        .padding()
        .screenBackground()
}
