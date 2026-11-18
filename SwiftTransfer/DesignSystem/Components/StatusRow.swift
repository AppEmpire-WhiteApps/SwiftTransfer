import SwiftUI

enum CheckStatus: Equatable {
    case pending
    case running
    case ok
    case warning
    case failed
}

/// A row with an animated status icon, title and detail — used by the connection check.
struct StatusRow: View {
    let title: LocalizedStringKey
    var detail: Text?
    let status: CheckStatus

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            icon
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                if let detail {
                    detail
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(statusLabel))
    }

    @ViewBuilder
    private var icon: some View {
        switch status {
        case .pending:
            Image(systemName: "circle.dashed")
                .font(.title3)
                .foregroundStyle(AppColor.textTertiary)
        case .running:
            ProgressView()
                .tint(AppColor.primary)
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AppColor.success)
                .transition(.scale.combined(with: .opacity))
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(AppColor.warning)
                .transition(.scale.combined(with: .opacity))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AppColor.error)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var statusLabel: LocalizedStringKey {
        switch status {
        case .pending: "Waiting"
        case .running: "Checking"
        case .ok: "OK"
        case .warning: "Warning"
        case .failed: "Failed"
        }
    }
}

#Preview {
    VStack {
        StatusRow(title: "Wi-Fi", detail: Text("Connected"), status: .ok)
        StatusRow(title: "Local network", status: .running)
        StatusRow(title: "Battery", detail: Text("18%"), status: .warning)
        StatusRow(title: "Second device", status: .failed)
        StatusRow(title: "Speed test", status: .pending)
    }
    .cardStyle()
    .padding()
}
