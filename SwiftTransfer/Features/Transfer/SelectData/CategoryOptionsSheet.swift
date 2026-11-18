import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Per-category options (TZ §4.3.2): accounts, calendars and period, lists, albums, manual picks,
/// quality and the file picker.
struct CategoryOptionsSheet: View {
    let category: DataCategory
    @Binding var selection: TransferSelection
    var onDone: () -> Void

    @State private var options = OptionsData()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsFileImporter = false
    @State private var fileImportError: String?

    var body: some View {
        NavigationStack {
            Form {
                switch category {
                case .contacts:
                    contactsSection
                case .calendar:
                    calendarSections
                case .reminders:
                    remindersSections
                case .photos:
                    photosSections
                case .videos:
                    videosSections
                case .files:
                    filesSection
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(Text(category.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
            .task {
                await options.load(for: category)
            }
        }
        .presentationDetents([.large])
        .trackScreen("select_data_options_\(category.rawValue)")
    }

    // MARK: Contacts

    @ViewBuilder
    private var contactsSection: some View {
        Section {
            if options.isLoading {
                ProgressView()
            }
            ForEach(options.containers) { container in
                Toggle(isOn: membership(\.contactContainerIDs, id: container.id, all: options.containers.map(\.id))) {
                    VStack(alignment: .leading) {
                        Text(container.name)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("\(container.contactCount) contacts")
                            .font(AppFont.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .tint(AppColor.primary)
            }
        } header: {
            Text("Accounts")
        } footer: {
            Text("Contacts are saved to a vCard file with photos.")
        }
    }

    // MARK: Calendar

    @ViewBuilder
    private var calendarSections: some View {
        Section {
            Picker(selection: $selection.calendarRange) {
                Text("Last year and all future").tag(TransferSelection.CalendarRange.lastYearAndFuture)
                Text("All events").tag(TransferSelection.CalendarRange.all)
                Text("Custom period").tag(TransferSelection.CalendarRange.custom)
            } label: {
                Text("Period")
            }
            if selection.calendarRange == .custom {
                DatePicker(
                    "From",
                    selection: dateBinding(\.customCalendarStart, fallback: Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now),
                    displayedComponents: .date
                )
                DatePicker(
                    "To",
                    selection: dateBinding(\.customCalendarEnd, fallback: Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now),
                    displayedComponents: .date
                )
            }
        } header: {
            Text("Period")
        }
        Section {
            if options.isLoading {
                ProgressView()
            }
            ForEach(options.calendars) { calendar in
                Toggle(isOn: calendarBinding(calendar)) {
                    HStack(spacing: Spacing.s) {
                        colorDot(calendar.color)
                        VStack(alignment: .leading) {
                            Text(calendar.title)
                                .foregroundStyle(AppColor.textPrimary)
                            Text(calendar.isReadOnlyFeed ? String(localized: "\(calendar.accountTitle) · subscribed") : calendar.accountTitle)
                                .font(AppFont.footnote)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
                .tint(AppColor.primary)
            }
        } header: {
            Text("Calendars")
        } footer: {
            Text("Subscribed and birthday calendars are off by default: they update themselves on the new phone.")
        }
    }

    // MARK: Reminders

    @ViewBuilder
    private var remindersSections: some View {
        Section {
            Toggle("Include completed", isOn: $selection.includeCompletedReminders)
                .tint(AppColor.primary)
        }
        Section {
            if options.isLoading {
                ProgressView()
            }
            ForEach(options.reminderLists) { list in
                Toggle(isOn: membership(\.reminderListIDs, id: list.id, all: options.reminderLists.map(\.id))) {
                    HStack(spacing: Spacing.s) {
                        colorDot(list.color)
                        Text(list.title)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
                .tint(AppColor.primary)
            }
        } header: {
            Text("Lists")
        } footer: {
            Text("Android has no built-in reminders app: reminders are saved as an .ics file for Google Tasks or a calendar app, plus a readable checklist.")
        }
    }

    // MARK: Photos and videos

    @ViewBuilder
    private var photosSections: some View {
        Section {
            Picker(selection: photoScopeBinding) {
                Text("All photos").tag(PhotoScope.all)
                Text("Albums").tag(PhotoScope.albums)
                Text("Choose manually").tag(PhotoScope.manual)
            } label: {
                Text("Photos")
            }
            .pickerStyle(.segmented)
            if photoScope == .manual {
                let pickerTitle = selection.pickedAssetIDs?.isEmpty == false
                    ? String(localized: "\(selection.pickedAssetIDs?.count ?? 0) photos chosen")
                    : String(localized: "Choose photos")
                PhotosPicker(
                    selection: $pickerItems,
                    matching: .images,
                    preferredItemEncoding: .current,
                    photoLibrary: .shared()
                ) {
                    Label(pickerTitle, systemImage: "photo.on.rectangle.angled")
                }
                .onChange(of: pickerItems) { _, items in
                    selection.pickedAssetIDs = items.compactMap(\.itemIdentifier)
                }
            }
            Toggle("Include hidden photos", isOn: $selection.includeHiddenPhotos)
                .tint(AppColor.primary)
        } footer: {
            if PermissionsService().status(.photos) == .limited {
                Text("Only the photos you allowed are available. You can allow full access in Settings.")
            }
        }
        if photoScope == .albums {
            albumsSection(isVideo: false)
        }
        qualitySection(
            quality: $selection.photoQuality,
            footer: "Compatible converts HEIC to JPEG for older Android phones and computers. Original keeps the best quality."
        )
    }

    @ViewBuilder
    private var videosSections: some View {
        Section {
            Toggle("Only videos from albums", isOn: Binding(
                get: { selection.videoAlbumIDs != nil },
                set: { selection.videoAlbumIDs = $0 ? [] : nil }
            ))
            .tint(AppColor.primary)
        }
        if selection.videoAlbumIDs != nil {
            albumsSection(isVideo: true)
        }
        qualitySection(
            quality: $selection.videoQuality,
            footer: "Compatible converts videos to H.264. It takes longer and the files may get bigger."
        )
    }

    private func albumsSection(isVideo: Bool) -> some View {
        Section {
            if options.isLoading {
                ProgressView()
            }
            ForEach(options.albums.filter { isVideo ? $0.videoCount > 0 : $0.photoCount > 0 }) { album in
                Toggle(isOn: albumBinding(album.id, isVideo: isVideo)) {
                    VStack(alignment: .leading) {
                        Text(album.title)
                            .foregroundStyle(AppColor.textPrimary)
                        Text(isVideo ? String(localized: "\(album.videoCount) videos") : String(localized: "\(album.photoCount) photos"))
                            .font(AppFont.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .tint(AppColor.primary)
            }
        } header: {
            Text("Albums")
        }
    }

    private func qualitySection(quality: Binding<MediaQuality>, footer: LocalizedStringKey) -> some View {
        Section {
            Picker(selection: quality) {
                ForEach(MediaQuality.allCases, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            } label: {
                Text("Quality")
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Quality")
        } footer: {
            Text(footer)
        }
    }

    // MARK: Files

    @ViewBuilder
    private var filesSection: some View {
        Section {
            ForEach(selection.fileURLs, id: \.self) { url in
                Label(url.lastPathComponent, systemImage: url.hasDirectoryPath ? "folder" : "doc")
                    .foregroundStyle(AppColor.textPrimary)
            }
            .onDelete { offsets in
                selection.fileURLs.remove(atOffsets: offsets)
            }
            Button {
                showsFileImporter = true
            } label: {
                Label("Add files or folders", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Chosen files")
        } footer: {
            if let fileImportError {
                Text(fileImportError)
                    .foregroundStyle(AppColor.error)
            } else {
                Text("Pick documents from Files, iCloud Drive or a connected drive. Folders are copied with their contents.")
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.item, .folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                fileImportError = nil
                for url in urls where !selection.fileURLs.contains(url) {
                    selection.fileURLs.append(url)
                }
            case .failure(let error):
                fileImportError = error.localizedDescription
            }
        }
    }

    // MARK: Bindings

    private enum PhotoScope: Hashable {
        case all
        case albums
        case manual
    }

    private var photoScope: PhotoScope {
        if selection.pickedAssetIDs != nil {
            return .manual
        }
        return selection.photoAlbumIDs != nil ? .albums : .all
    }

    private var photoScopeBinding: Binding<PhotoScope> {
        Binding {
            photoScope
        } set: { scope in
            switch scope {
            case .all:
                selection.pickedAssetIDs = nil
                selection.photoAlbumIDs = nil
            case .albums:
                selection.pickedAssetIDs = nil
                selection.photoAlbumIDs = selection.photoAlbumIDs ?? []
            case .manual:
                selection.pickedAssetIDs = selection.pickedAssetIDs ?? []
            }
        }
    }

    /// Toggle membership in an optional ID set where nil means "all".
    private func membership(
        _ keyPath: WritableKeyPath<TransferSelection, Set<String>?>,
        id: String,
        all: [String]
    ) -> Binding<Bool> {
        Binding {
            selection[keyPath: keyPath]?.contains(id) ?? true
        } set: { isOn in
            var ids = selection[keyPath: keyPath] ?? Set(all)
            if isOn {
                ids.insert(id)
            } else {
                ids.remove(id)
            }
            selection[keyPath: keyPath] = ids.count == all.count ? nil : ids
        }
    }

    /// Calendars: nil means "all except subscribed/birthday feeds".
    private func calendarBinding(_ calendar: CalendarInfo) -> Binding<Bool> {
        let defaults = Set(options.calendars.filter { !$0.isReadOnlyFeed }.map(\.id))
        return Binding {
            selection.calendarIDs?.contains(calendar.id) ?? defaults.contains(calendar.id)
        } set: { isOn in
            var ids = selection.calendarIDs ?? defaults
            if isOn {
                ids.insert(calendar.id)
            } else {
                ids.remove(calendar.id)
            }
            selection.calendarIDs = ids == defaults ? nil : ids
        }
    }

    private func albumBinding(_ id: String, isVideo: Bool) -> Binding<Bool> {
        let keyPath: WritableKeyPath<TransferSelection, Set<String>?> = isVideo ? \.videoAlbumIDs : \.photoAlbumIDs
        return Binding {
            selection[keyPath: keyPath]?.contains(id) ?? false
        } set: { isOn in
            var ids = selection[keyPath: keyPath] ?? []
            if isOn {
                ids.insert(id)
            } else {
                ids.remove(id)
            }
            selection[keyPath: keyPath] = ids
        }
    }

    private func dateBinding(_ keyPath: WritableKeyPath<TransferSelection, Date?>, fallback: Date) -> Binding<Date> {
        Binding {
            selection[keyPath: keyPath] ?? fallback
        } set: { value in
            selection[keyPath: keyPath] = value
        }
    }

    private func colorDot(_ components: [Double]) -> some View {
        Circle()
            .fill(components.count >= 3 ? Color(red: components[0], green: components[1], blue: components[2]) : AppColor.sky)
            .frame(width: 12, height: 12)
            .accessibilityHidden(true)
    }
}

/// Lists loaded for the options sheet.
@MainActor
@Observable
final class OptionsData {
    var containers: [ContactContainerInfo] = []
    var calendars: [CalendarInfo] = []
    var reminderLists: [ReminderListInfo] = []
    var albums: [PhotoAlbumInfo] = []
    var isLoading = false

    func load(for category: DataCategory) async {
        isLoading = true
        defer { isLoading = false }
        switch category {
        case .contacts:
            containers = (try? await ContactsSource().containers()) ?? []
        case .calendar:
            calendars = await CalendarSource().calendars()
        case .reminders:
            reminderLists = await RemindersSource().lists()
        case .photos, .videos:
            albums = await Task.detached(priority: .userInitiated) {
                PhotosSource().albums()
            }.value
        case .files:
            break
        }
    }
}

#Preview {
    @Previewable @State var selection = TransferSelection()
    CategoryOptionsSheet(category: .calendar, selection: $selection) {}
        .environment(AppActivityContext())
}
