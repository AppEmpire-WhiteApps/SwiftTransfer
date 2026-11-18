import Foundation
import Observation

/// State of the data selection screen (S5): permissions and asynchronous counts/sizes per category.
@MainActor
@Observable
final class SelectDataModel {
    struct CategoryState: Equatable {
        /// Nil for categories without a system permission (files).
        var permission: PermissionState?
        var summary: CategorySummary?
        var isFinal = false

        var isLoading: Bool {
            summary == nil && (permission?.allowsAccess ?? true)
        }

        var hasNoData: Bool {
            isFinal && (summary?.itemCount ?? 0) == 0
        }
    }

    /// Default transfer speed for estimates when no speed test result exists (TZ §4.3.1).
    static let defaultBytesPerSecond: Double = 15_000_000

    private(set) var states: [DataCategory: CategoryState] = [:]
    private let service: ExportService
    private let permissions = PermissionsService()
    private let isPreview: Bool
    private var loadTasks: [DataCategory: Task<Void, Never>] = [:]

    init(service: ExportService = ExportService()) {
        self.service = service
        self.isPreview = false
        refreshPermissions()
    }

    private init(previewStates: [DataCategory: CategoryState]) {
        self.service = ExportService()
        self.isPreview = true
        self.states = previewStates
    }

    func state(_ category: DataCategory) -> CategoryState {
        states[category] ?? CategoryState()
    }

    // MARK: Permissions

    func refreshPermissions() {
        guard !isPreview else { return }
        for category in DataCategory.allCases {
            var state = states[category] ?? CategoryState()
            state.permission = PermissionKind.reading(category).map(permissions.status)
            states[category] = state
        }
    }

    /// Shows the system prompt and returns the resulting state.
    func requestAccess(for category: DataCategory) async -> PermissionState {
        guard let kind = PermissionKind.reading(category) else { return .authorized }
        let result = await permissions.request(kind)
        refreshPermissions()
        // Photos and videos share one permission.
        if kind == .photos {
            states[.photos]?.summary = nil
            states[.videos]?.summary = nil
        }
        return result
    }

    // MARK: Loading

    /// Loads every category; when `selection.defaultsApplied` is false, selects everything available.
    func start(selection: TransferSelection, update: (TransferSelection) -> Void) {
        guard !isPreview else { return }
        refreshPermissions()
        if !selection.defaultsApplied {
            var updated = selection
            for category in DataCategory.allCases where category != .files {
                if state(category).permission?.allowsAccess == true {
                    updated.categories.insert(category)
                }
            }
            if !selection.fileURLs.isEmpty {
                updated.categories.insert(.files)
            }
            updated.defaultsApplied = true
            update(updated)
        }
        for category in DataCategory.allCases where states[category]?.summary == nil || states[category]?.isFinal == false {
            reload(category, selection: selection)
        }
    }

    func reload(_ category: DataCategory, selection: TransferSelection) {
        guard !isPreview else { return }
        loadTasks[category]?.cancel()
        var state = states[category] ?? CategoryState()
        state.permission = PermissionKind.reading(category).map(permissions.status)
        guard state.permission?.allowsAccess ?? true else {
            state.summary = nil
            state.isFinal = true
            states[category] = state
            return
        }
        state.summary = nil
        state.isFinal = false
        states[category] = state

        let updates = service.summaryUpdates(for: category, selection: selection)
        loadTasks[category] = Task { [weak self] in
            for await update in updates {
                guard !Task.isCancelled else { return }
                self?.states[category]?.summary = update.summary
                self?.states[category]?.isFinal = update.isFinal
            }
        }
    }

    /// Selected categories that turned out to be empty (they are shown as "No data" and deselected).
    func emptySelectedCategories(in selection: TransferSelection) -> [DataCategory] {
        selection.categories.filter { $0 != .files && state($0).hasNoData }
    }

    func cancelAll() {
        loadTasks.values.forEach { $0.cancel() }
        loadTasks.removeAll()
    }

    // MARK: Totals

    func totalBytes(for selection: TransferSelection) -> Int64 {
        selection.categories.reduce(0) { $0 + (state($1).summary?.byteCount ?? 0) }
    }

    func totalItems(for selection: TransferSelection) -> Int {
        selection.categories.reduce(0) { $0 + (state($1).summary?.itemCount ?? 0) }
    }

    func isCalculating(_ selection: TransferSelection) -> Bool {
        selection.categories.contains { !state($0).isFinal }
    }

    static func estimatedSeconds(bytes: Int64, bytesPerSecond: Double = defaultBytesPerSecond) -> Double {
        Double(bytes) / bytesPerSecond
    }

    /// Free space to ask for on an Android receiver: total plus 10%, rounded up to whole GB.
    static func recommendedFreeGigabytes(bytes: Int64) -> Int {
        let gigabytes = Double(bytes) * 1.1 / 1_000_000_000
        return max(1, Int(gigabytes.rounded(.up)))
    }

    // MARK: Preview

    static func preview() -> SelectDataModel {
        SelectDataModel(previewStates: [
            .contacts: CategoryState(permission: .authorized, summary: CategorySummary(itemCount: 1245, byteCount: 3_700_000), isFinal: true),
            .calendar: CategoryState(permission: .authorized, summary: CategorySummary(itemCount: 312, byteCount: 280_000), isFinal: true),
            .reminders: CategoryState(permission: .notDetermined, summary: nil, isFinal: false),
            .photos: CategoryState(permission: .limited, summary: CategorySummary(itemCount: 8_420, byteCount: 21_400_000_000), isFinal: false),
            .videos: CategoryState(permission: .denied, summary: nil, isFinal: true),
            .files: CategoryState(permission: nil, summary: CategorySummary(itemCount: 0, byteCount: 0), isFinal: true),
        ])
    }
}
