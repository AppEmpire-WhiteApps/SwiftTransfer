import SwiftUI

/// Screen S5 "What to transfer" (TZ §4.3): categories with counts and sizes, permissions,
/// per-category options, "What can't be transferred" and a sticky bottom bar.
struct SelectDataView: View {
    @Binding var selection: TransferSelection
    let target: TransferTarget
    let onContinue: () -> Void

    @State private var model: SelectDataModel
    @State private var primerCategory: DataCategory?
    @State private var detailCategory: DataCategory?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppRouter.self) private var router

    init(selection: Binding<TransferSelection>, target: TransferTarget, onContinue: @escaping () -> Void) {
        self._selection = selection
        self.target = target
        self.onContinue = onContinue
        self._model = State(initialValue: SelectDataModel())
    }

    /// Preview/testing initializer with a prepared model.
    init(selection: Binding<TransferSelection>, target: TransferTarget, model: SelectDataModel, onContinue: @escaping () -> Void) {
        self._selection = selection
        self.target = target
        self.onContinue = onContinue
        self._model = State(initialValue: model)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: sizeClass == .regular ? 300 : 280), spacing: Spacing.l, alignment: .top)]
    }

    private var selectableCategories: [DataCategory] {
        DataCategory.allCases.filter { category in
            let state = model.state(category)
            return category != .files && (category != .photos || router.premiumAccess.isPremium)
                && state.permission?.allowsAccess == true && !state.hasNoData
        }
    }

    private var allSelected: Bool {
        !selectableCategories.isEmpty && selectableCategories.allSatisfy { selection.categories.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                LazyVGrid(columns: columns, spacing: Spacing.l) {
                    ForEach(DataCategory.allCases) { category in
                        CategorySelectionCard(
                            category: category,
                            state: model.state(category),
                            isSelected: selection.categories.contains(category),
                            onToggle: { isOn in toggle(category, isOn: isOn) },
                            onAllowAccess: {
                                guard category != .photos || router.premiumAccess.authorize(.photos) else { return }
                                primerCategory = category
                            },
                            onOptions: {
                                guard category != .photos || router.premiumAccess.authorize(.photos) else { return }
                                detailCategory = category
                            }
                        )
                        .accessibilityIdentifier("category.\(category.rawValue)")
                        .overlay(alignment: .topTrailing) {
                            if category == .photos && !router.premiumAccess.isPremium {
                                Button {
                                    _ = router.premiumAccess.authorize(.photos)
                                } label: {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(AppColor.primary)
                                        .padding(12)
                                }
                                .accessibilityLabel(Text("Photo transfer requires a subscription"))
                                .accessibilityIdentifier("photo.subscription")
                            }
                        }
                    }
                }
                if target == .android {
                    androidNote
                }
                safetyNote
                NotTransferableCard()
            }
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
            .pageMargins()
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .navigationTitle(Text("What to transfer"))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("select_data")
        .onAppear {
            model.start(selection: selection) { updated in
                var updated = updated
                if !router.premiumAccess.isPremium { updated.categories.remove(.photos) }
                selection = updated
            }
        }
        .onDisappear {
            model.cancelAll()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshAfterReturningFromSettings()
            }
        }
        .onChange(of: model.states) { _, _ in
            for category in model.emptySelectedCategories(in: selection) {
                selection.categories.remove(category)
            }
        }
        .sheet(item: $primerCategory) { category in
            primerSheet(for: category)
        }
        .sheet(item: $detailCategory, onDismiss: nil) { category in
            CategoryOptionsSheet(category: category, selection: $selection) {
                detailCategory = nil
                applyOptionsChange(for: category)
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Choose what to move")
                .font(AppFont.title1)
                .foregroundStyle(AppColor.textPrimary)
            Text("Everything available is selected. Your data stays on this iPhone — it is only copied.")
                .font(AppFont.callout)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(allSelected ? "Deselect all" : "Select all") {
                    toggleAll()
                }
                .buttonStyle(.text)
                .disabled(selectableCategories.isEmpty)
            }
        }
    }

    private var androidNote: some View {
        let gigabytes = SelectDataModel.recommendedFreeGigabytes(bytes: model.totalBytes(for: selection))
        return Label {
            Text("Make sure the Android phone has at least \(gigabytes) GB of free space.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "internaldrive")
                .foregroundStyle(AppColor.primary)
        }
        .font(AppFont.callout)
        .foregroundStyle(AppColor.textPrimary)
        .cardStyle(background: AppColor.skyMist)
    }

    private var safetyNote: some View {
        Label {
            Text("Transfer is copying. Nothing is changed or deleted on this device.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(AppColor.success)
        }
        .font(AppFont.footnote)
        .foregroundStyle(AppColor.textSecondary)
        .padding(.horizontal, Spacing.s)
    }

    private var bottomBar: some View {
        let bytes = model.totalBytes(for: selection)
        let items = model.totalItems(for: selection)
        let seconds = SelectDataModel.estimatedSeconds(bytes: bytes)
        return VStack(spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.textSecondary)
                    HStack(spacing: Spacing.xs) {
                        if model.isCalculating(selection) {
                            Text(verbatim: "≈")
                        }
                        Text(bytes, format: .byteCount(style: .file))
                    }
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Estimated time")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.textSecondary)
                    estimateText(seconds: seconds)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
            Button {
                guard router.premiumAccess.authorizePhotos(selection) else { return }
                onContinue()
            } label: {
                Text("Transfer")
            }
            .buttonStyle(.primary)
            .disabled(selection.categories.isEmpty || (items == 0 && !model.isCalculating(selection)))
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.m)
        .padding(.bottom, Spacing.s)
        .pageMargins()
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppColor.divider)
                        .frame(height: 1)
                }
                .ignoresSafeArea()
        }
    }

    private func estimateText(seconds: Double) -> Text {
        if seconds < 60 {
            return Text("Under a minute")
        }
        return Text(
            Duration.seconds(seconds.rounded()),
            format: .units(allowed: [.hours, .minutes], width: .abbreviated, maximumUnitCount: 2)
        )
    }

    private func primerSheet(for category: DataCategory) -> some View {
        let kind = PermissionKind.reading(category) ?? .photos
        return PermissionPrimerView(
            kind: kind,
            state: model.state(category).permission ?? .notDetermined,
            onAllow: {
                guard category != .photos || router.premiumAccess.authorize(.photos) else { return }
                Task {
                    let result = await model.requestAccess(for: category)
                    primerCategory = nil
                    if result.allowsAccess {
                        accessGranted(kind: kind)
                    }
                }
            },
            onClose: { primerCategory = nil }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Actions

    private func toggle(_ category: DataCategory, isOn: Bool) {
        if isOn, category == .photos, !router.premiumAccess.authorize(.photos) { return }
        let state = model.state(category)
        if isOn {
            if state.permission == .notDetermined {
                primerCategory = category
                return
            }
            if category == .files && selection.fileURLs.isEmpty {
                detailCategory = .files
                return
            }
            selection.categories.insert(category)
        } else {
            selection.categories.remove(category)
        }
    }

    private func toggleAll() {
        if allSelected {
            for category in selectableCategories {
                selection.categories.remove(category)
            }
        } else {
            selection.categories.formUnion(selectableCategories)
        }
    }

    private func accessGranted(kind: PermissionKind) {
        for category in DataCategory.allCases where PermissionKind.reading(category) == kind {
            if category == .photos && !router.premiumAccess.isPremium { continue }
            selection.categories.insert(category)
            model.reload(category, selection: selection)
        }
    }

    private func applyOptionsChange(for category: DataCategory) {
        if category == .files {
            if selection.fileURLs.isEmpty {
                selection.categories.remove(.files)
            } else {
                selection.categories.insert(.files)
            }
        }
        model.reload(category, selection: selection)
    }

    private func refreshAfterReturningFromSettings() {
        let before = model.states.mapValues(\.permission)
        model.refreshPermissions()
        for category in DataCategory.allCases where before[category] != model.state(category).permission {
            model.reload(category, selection: selection)
        }
    }
}

#Preview("iPhone → Android") {
    @Previewable @State var selection = TransferSelection(categories: [.contacts, .calendar, .photos], defaultsApplied: true)
    NavigationStack {
        SelectDataView(selection: $selection, target: .android, model: .preview()) {}
    }
    .environment(AppRouter())
    .environment(AppActivityContext())
}
