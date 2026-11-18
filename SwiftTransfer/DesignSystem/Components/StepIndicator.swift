import SwiftUI

/// The 4-step indicator from the reference: Launch → Connect → Select → Transfer.
struct StepIndicator: View {
    enum Step: Int, CaseIterable {
        case launch
        case connect
        case select
        case transfer

        var title: LocalizedStringKey {
            switch self {
            case .launch: "Launch"
            case .connect: "Connect"
            case .select: "Select"
            case .transfer: "Transfer"
            }
        }
    }

    let current: Step

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Step.allCases, id: \.self) { step in
                VStack(spacing: Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(fill(for: step))
                            .frame(width: 28, height: 28)
                        if step.rawValue < current.rawValue {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(step.rawValue + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(step == current ? .white : AppColor.textSecondary)
                        }
                    }
                    Text(step.title)
                        .font(AppFont.caption)
                        .foregroundStyle(step == current ? AppColor.primary : AppColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    if step != Step.allCases.last {
                        Capsule()
                            .fill(step.rawValue < current.rawValue ? AppColor.primary : AppColor.divider)
                            .frame(height: 2)
                            .offset(y: 13)
                            .padding(.leading, 60)
                            .padding(.trailing, -24)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(current.rawValue + 1) of 4"))
        .animation(.spring(duration: 0.4, bounce: 0.2), value: current)
    }

    private func fill(for step: Step) -> AnyShapeStyle {
        if step.rawValue <= current.rawValue {
            AnyShapeStyle(AppGradient.primary)
        } else {
            AnyShapeStyle(AppColor.skyLight)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        StepIndicator(current: .launch)
        StepIndicator(current: .select)
        StepIndicator(current: .transfer)
    }
    .padding()
}
