import Foundation

/// What the user chose to transfer and how. Owned by the data layer; transports read `categories`.
struct TransferSelection: Sendable, Equatable {
    enum CalendarRange: String, Sendable, CaseIterable {
        case lastYearAndFuture
        case all
        /// Uses `customCalendarStart` / `customCalendarEnd`.
        case custom
    }

    var categories: Set<DataCategory> = []
    /// Nil means "all eligible containers/calendars/lists/albums".
    var contactContainerIDs: Set<String>?
    var calendarIDs: Set<String>?
    var calendarRange: CalendarRange = .lastYearAndFuture
    var reminderListIDs: Set<String>?
    var includeCompletedReminders = false
    var photoAlbumIDs: Set<String>?
    /// Manually picked assets (PhotosPicker); overrides albums when non-nil.
    var pickedAssetIDs: [String]?
    var photoQuality: MediaQuality = .original
    var videoQuality: MediaQuality = .original
    var includeHiddenPhotos = false
    var fileURLs: [URL] = []

    // MARK: Added by the data layer

    /// Inclusive start/end days of `CalendarRange.custom`.
    var customCalendarStart: Date?
    var customCalendarEnd: Date?
    /// Optional creation-date filter for photos (nil = any date).
    var photoDateRange: ClosedRange<Date>?
    /// Nil means all videos; otherwise videos from these albums.
    var videoAlbumIDs: Set<String>?
    /// Optional creation-date filter for videos (nil = any date).
    var videoDateRange: ClosedRange<Date>?
    /// True once the selection screen applied its defaults ("everything available is selected").
    var defaultsApplied = false
}
