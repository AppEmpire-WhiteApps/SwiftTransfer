import SwiftUI

/// Circular progress with a blue gradient stroke and a percentage in the middle.
struct ProgressRing: View {
    /// 0...1
    let progress: Double
    var lineWidth: CGFloat = 16
    var showsPercentage = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColor.skyLight, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(
                        colors: [AppColor.sky, AppColor.primary, AppColor.sky],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            if showsPercentage {
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(AppFont.metric)
                    .foregroundStyle(AppColor.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.default, value: progress)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress"))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview {
    ProgressRing(progress: 0.42)
        .frame(width: 220, height: 220)
        .padding()
}
