import SwiftUI

/// One category on the selection screen: 3D icon, title, count and size, toggle and options.
struct CategorySelectionCard: View {
    let category: DataCategory
    let state: SelectDataModel.CategoryState
    let isSelected: Bool
    var onToggle: (Bool) -> Void
    var onAllowAccess: () -> Void
    var onOptions: () -> Void

    private var isDisabled: Bool {
        if state.permission?.isBlocked == true {
            return true
        }
        return category != .files && state.hasNoData
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .center, spacing: Spacing.m) {
                category.illustration.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .saturation(isDisabled ? 0.2 : 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    subtitle
                        .font(AppFont.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.s)
                Toggle(isOn: Binding(get: { isSelected }, set: { onToggle($0) })) {
                    Text(category.title)
                }
                .labelsHidden()
                .tint(AppColor.primary)
                .disabled(isDisabled)
            }
            actionRow
        }
        .cardStyle()
        .opacity(isDisabled ? 0.75 : 1)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var subtitle: some View {
        if let permission = state.permission, permission == .notDetermined {
            Text("Access needed")
                .foregroundStyle(AppColor.textSecondary)
        } else if state.permission?.isBlocked == true {
            Text("No access")
                .foregroundStyle(AppColor.error)
        } else if let summary = state.summary {
            if summary.itemCount == 0 && state.isFinal {
                Text(category == .files ? "No files chosen" : "No data")
                    .foregroundStyle(AppColor.textTertiary)
            } else {
                HStack(spacing: Spacing.xs) {
                    Text(countText(summary.itemCount))
                    Text(verbatim: "·")
                    if !state.isFinal {
                        Text(verbatim: "≈")
                    }
                    Text(summary.byteCount, format: .byteCount(style: .file))
                }
                .foregroundStyle(AppColor.textSecondary)
                .monospacedDigit()
            }
        } else {
            Text(verbatim: "0000 items · 00.0 MB")
                .foregroundStyle(AppColor.textSecondary)
                .redacted(reason: .placeholder)
                .accessibilityLabel(Text("Counting…"))
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: Spacing.s) {
            if state.permission == .notDetermined {
                pill("Allow access", systemImage: "hand.raised.fill", action: onAllowAccess)
            } else if state.permission?.isBlocked == true {
                pill("Open Settings", systemImage: "gear") {
                    PermissionsService.openSettings()
                }
            } else {
                if state.permission == .limited {
                    Label("Limited access", systemImage: "exclamationmark.circle")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.warning)
                }
                Spacer(minLength: 0)
                if category == .files {
                    pill("Choose files", systemImage: "plus", action: onOptions)
                } else if !state.hasNoData {
                    pill("Options", systemImage: "slider.horizontal.3", action: onOptions)
                }
            }
        }
    }

    private func pill(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chip(title: Text(title), systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func countText(_ count: Int) -> LocalizedStringKey {
        switch category {
        case .contacts: "\(count) contacts"
        case .calendar: "\(count) events"
        case .reminders: "\(count) reminders"
        case .photos: "\(count) photos"
        case .videos: "\(count) videos"
        case .files: "\(count) files"
        }
    }
}

#Preview {
    let model = SelectDataModel.preview()
    ScrollView {
        VStack(spacing: Spacing.l) {
            ForEach(DataCategory.allCases) { category in
                CategorySelectionCard(
                    category: category,
                    state: model.state(category),
                    isSelected: category == .contacts,
                    onToggle: { _ in },
                    onAllowAccess: {},
                    onOptions: {}
                )
            }
        }
        .padding()
    }
    .screenBackground()
}
