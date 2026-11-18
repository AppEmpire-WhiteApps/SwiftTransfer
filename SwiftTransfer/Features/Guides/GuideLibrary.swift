import Foundation

/// Content of all built-in guides. Strings are localizable literals extracted into the String Catalog.
enum GuideLibrary {
    static let all: [Guide] = GuideID.allCases.map(makeGuide)

    static func guide(_ id: GuideID) -> Guide {
        all.first { $0.id == id } ?? makeGuide(id)
    }

    /// Guides whose title, summary or steps contain `query` (case- and diacritic-insensitive).
    static func search(_ query: String) -> [Guide] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { guide in
            searchableText(of: guide).contains { matches($0, query: trimmed) }
        }
    }

    /// FAQ answers whose question or answer contains `query`.
    static func searchFAQ(_ query: String) -> [GuideFAQItem] {
        let items = guide(.faq).faq
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            matches(String(localized: item.question), query: trimmed)
                || matches(String(localized: item.answer), query: trimmed)
        }
    }

    private static func searchableText(of guide: Guide) -> [String] {
        var texts = [String(localized: guide.title), String(localized: guide.summary)]
        for step in guide.steps {
            texts.append(String(localized: step.title))
            texts.append(String(localized: step.text))
        }
        for item in guide.faq {
            texts.append(String(localized: item.question))
        }
        return texts
    }

    private static func matches(_ text: String, query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func makeGuide(_ id: GuideID) -> Guide {
        switch id {
        case .wifiGalaxy: wifiToAndroid
        case .cableGalaxy: cableToAndroid
        case .storage: externalDrive
        case .androidIphone: androidToIPhone
        case .hotspot: hotspot
        case .importSamsung: importOnAndroid
        case .notTransferable: notTransferable
        case .faq: faq
        }
    }
}

// MARK: - iPhone → Android over Wi-Fi

private extension GuideLibrary {
    static var wifiToAndroid: Guide {
        Guide(
            id: .wifiGalaxy,
            summary: "Send contacts, calendar, photos and videos to any Android phone through its browser. No app is needed on Android.",
            steps: [
                GuideStep(
                    title: "Open the app on your iPhone",
                    text: "Tap Send data and choose Android. Connect both phones to the same Wi-Fi network. No router nearby? One phone can share a Personal Hotspot.",
                    illustration: .methodWifi,
                    phase: .launch,
                    action: .guide(.hotspot, title: "Transfer without a router")
                ),
                GuideStep(
                    title: "Scan the QR code on Android",
                    text: "Open the camera or a QR scanner on your Android phone (e.g. Samsung Galaxy) and point it at the code on the iPhone. The transfer page opens in the browser.",
                    illustration: .connectQR,
                    phase: .connect
                ),
                GuideStep(
                    title: "Confirm the connection",
                    text: "The iPhone asks whether to let the new device connect. Check that the code on both screens matches and tap Allow.",
                    illustration: .stepTrust,
                    phase: .connect
                ),
                GuideStep(
                    title: "Choose what to move",
                    text: "Pick contacts, calendar, photos, videos and files. You'll see the total size and an estimate of how long it takes.",
                    illustration: .stepSelect,
                    phase: .select
                ),
                GuideStep(
                    title: "Keep both screens on",
                    text: "Keep the app open and the phones close to each other. The Android browser downloads the files in batches. Make sure Android has enough free space.",
                    illustration: .stepProgress,
                    phase: .transfer,
                    action: .action(.openConnectionCheck)
                ),
                GuideStep(
                    title: "Import on Android",
                    text: "Open the downloaded files: contacts (.vcf) go to Contacts, events (.ics) to Calendar, photos and videos appear in the Gallery.",
                    illustration: .stepFiles,
                    phase: .transfer,
                    action: .guide(.importSamsung, title: "How to import on Android")
                ),
            ],
            transferStart: .send(.android)
        )
    }
}

// MARK: - iPhone → Android by cable

private extension GuideLibrary {
    static var cableToAndroid: Guide {
        Guide(
            id: .cableGalaxy,
            summary: "Wired transfer with the Android phone's own migration app, e.g. Smart Switch on Samsung Galaxy, and how this app helps you prepare.",
            steps: [
                GuideStep(
                    title: "Prepare both phones",
                    text: "Charge both phones and update them. If you move your SIM card to Android, turn off iMessage and FaceTime on the iPhone first so messages from iPhone users reach you.",
                    illustration: .stepSettings,
                    phase: .launch
                ),
                GuideStep(
                    title: "Pick the right cable",
                    text: "USB-C to USB-C for iPhone 15 and newer. Lightning to USB-C for older iPhones. If you only have a USB-A cable, use the USB OTG adapter that often comes in the Android phone's box.",
                    illustration: .methodCable,
                    phase: .connect
                ),
                GuideStep(
                    title: "Start Smart Switch on the Galaxy",
                    text: "On a Samsung Galaxy, open Smart Switch (preinstalled, or from Google Play). Choose Receive data, then iPhone/iPad, then Cable. Connect the cable to both phones.",
                    illustration: .deviceAndroid,
                    phase: .connect
                ),
                GuideStep(
                    title: "Tap “Trust this computer”",
                    text: "When the iPhone asks “Trust this computer?”, tap Trust and enter your passcode. Without this the Android phone can't read any data.",
                    illustration: .stepTrust,
                    phase: .connect
                ),
                GuideStep(
                    title: "Choose what to move",
                    text: "Smart Switch can move contacts, calendar, photos, videos, messages, notes, Wi-Fi networks and a list of your apps to find on Google Play. Photos stored only in iCloud must be downloaded to the iPhone first.",
                    illustration: .stepSelect,
                    phase: .select
                ),
                GuideStep(
                    title: "Other Android brands",
                    text: "Google Pixel: use “Copy apps & data” during setup, with a cable. Xiaomi and Redmi, OnePlus, Oppo and Realme, Honor and Huawei have their own clone apps (e.g. Mi Mover, Clone Phone, Phone Clone). Follow the steps in that app.",
                    illustration: .transferDevices,
                    phase: .transfer
                ),
                GuideStep(
                    title: "How this app helps",
                    text: "Use this app to prepare: check what iOS can't move, save contacts, calendars and photos to a USB drive as a backup, and send anything the cable missed over Wi-Fi.",
                    illustration: .storageDrive,
                    phase: .transfer,
                    action: .guide(.notTransferable, title: "What iOS can't transfer")
                ),
            ],
            transferStart: .send(nil)
        )
    }
}

// MARK: - External drive

private extension GuideLibrary {
    static var externalDrive: Guide {
        Guide(
            id: .storage,
            summary: "Save your data to a USB drive as readable files and restore it on any phone or computer.",
            steps: [
                GuideStep(
                    title: "Connect a drive",
                    text: "Plug a USB-C flash drive or SSD into the iPhone. For a Lightning iPhone, use a Lightning to USB camera adapter with power. The drive should appear in the Files app.",
                    illustration: .storageDrive,
                    phase: .launch
                ),
                GuideStep(
                    title: "Choose the drive",
                    text: "In the app, tap Send data, choose External drive and pick a folder on the drive.",
                    illustration: .deviceStorage,
                    phase: .connect,
                    action: .route(.externalStorage, title: "Open Cable & drive", systemImage: "externaldrive")
                ),
                GuideStep(
                    title: "Select data",
                    text: "Contacts are saved as .vcf, events as .ics, photos and videos as originals or compatible copies. Check that the drive has enough free space.",
                    illustration: .stepSelect,
                    phase: .select
                ),
                GuideStep(
                    title: "Wait for the export",
                    text: "Keep the app open. An export folder with ordinary files is created on the drive, so it opens on any computer or phone.",
                    illustration: .stepProgress,
                    phase: .transfer
                ),
                GuideStep(
                    title: "Restore on the new phone",
                    text: "To restore from the drive, open Cable & drive and choose Restore from a drive. On Android, connect the drive, open the exported files and import contacts and events; copy photos to the gallery.",
                    illustration: .stepFiles,
                    phase: .transfer,
                    action: .guide(.importSamsung, title: "How to import on Android")
                ),
            ],
            transferStart: .send(.storage)
        )
    }
}

// MARK: - Android → iPhone

private extension GuideLibrary {
    static var androidToIPhone: Guide {
        Guide(
            id: .androidIphone,
            summary: "Upload photos, videos, contacts and calendars from any Android phone to your iPhone through the browser.",
            steps: [
                GuideStep(
                    title: "Open Receive data on the iPhone",
                    text: "Tap Receive data and choose Android. Connect both phones to the same Wi-Fi network or a Personal Hotspot.",
                    illustration: .deviceIphone,
                    phase: .launch
                ),
                GuideStep(
                    title: "Scan the QR code on Android",
                    text: "Open the camera on the Android phone and scan the code. An upload page opens in the browser.",
                    illustration: .connectQR,
                    phase: .connect
                ),
                GuideStep(
                    title: "Choose files to upload",
                    text: "Add photos, videos, contacts (.vcf) and calendar (.ics) files on the page. To get a .vcf file, export contacts in the Contacts app on Android.",
                    illustration: .stepSelect,
                    phase: .select
                ),
                GuideStep(
                    title: "Keep the page open",
                    text: "Files go straight to the iPhone and are imported into Photos, Contacts and Calendar.",
                    illustration: .stepProgress,
                    phase: .transfer
                ),
                GuideStep(
                    title: "Check the result",
                    text: "Open Photos and Contacts on the iPhone. If something went wrong, you can undo the import in History within 24 hours.",
                    illustration: .success,
                    phase: .transfer,
                    action: .route(.history, title: "Open history", systemImage: "clock.arrow.circlepath")
                ),
            ],
            transferStart: .receive(.android)
        )
    }
}

// MARK: - Personal Hotspot

private extension GuideLibrary {
    static var hotspot: Guide {
        Guide(
            id: .hotspot,
            summary: "No Wi-Fi router? One phone shares a hotspot and the other joins it. Mobile data isn't used for the transfer.",
            steps: [
                GuideStep(
                    title: "Turn on Personal Hotspot",
                    text: "On an iPhone: Settings, Personal Hotspot, turn on Allow Others to Join. On Android: Settings, Network or Connections, Hotspot.",
                    illustration: .connectHotspot,
                    phase: .launch
                ),
                GuideStep(
                    title: "Connect the other phone",
                    text: "On the second phone, join the hotspot's Wi-Fi network with the password shown on the first phone.",
                    illustration: .methodWifi,
                    phase: .connect
                ),
                GuideStep(
                    title: "Start the transfer as usual",
                    text: "On the iPhone, open the app and choose Send data or Receive data, then Android. Scan the QR code with the Android phone to open the transfer page in its browser. Data goes directly between the phones.",
                    illustration: .connectQR,
                    phase: .select
                ),
                GuideStep(
                    title: "Keep the phones close",
                    text: "Keep the phones next to each other and connected to chargers if possible. Run the connection check to see the expected time.",
                    illustration: .stepProgress,
                    phase: .transfer,
                    action: .action(.openConnectionCheck)
                ),
            ],
            transferStart: .send(nil)
        )
    }
}

// MARK: - Import files on Android

private extension GuideLibrary {
    static var importOnAndroid: Guide {
        Guide(
            id: .importSamsung,
            summary: "Where the received files are and how to add contacts, events and photos on any Android phone.",
            steps: [
                GuideStep(
                    title: "Find the received files",
                    text: "Files downloaded in the browser are in the Downloads folder of the Files or My Files app. From a drive, open the export folder created by the app.",
                    illustration: .stepFiles
                ),
                GuideStep(
                    title: "Import contacts (.vcf)",
                    text: "Tap the .vcf file and open it with Contacts or Google Contacts. Choose your Google account so the contacts stay synced and backed up.",
                    illustration: .contacts
                ),
                GuideStep(
                    title: "Import events (.ics)",
                    text: "Open the .ics file with Google Calendar or your phone's calendar app and choose the calendar to save the events to.",
                    illustration: .calendar
                ),
                GuideStep(
                    title: "Photos and videos",
                    text: "Photos and videos from the Downloads folder show up in the Gallery and Google Photos. Move them to an album or back them up with Google Photos.",
                    illustration: .photos
                ),
                GuideStep(
                    title: "Tips for popular phones",
                    text: "Samsung: My Files, then Downloads; Contacts, Manage contacts, Import contacts. Xiaomi: File Manager; Contacts, Settings, Import. Google Pixel: Files by Google; Contacts, Fix & manage, Import from file.",
                    illustration: .deviceAndroid
                ),
            ],
            transferStart: .send(.android)
        )
    }
}

// MARK: - What iOS can't transfer

private extension GuideLibrary {
    static var notTransferable: Guide {
        Guide(
            id: .notTransferable,
            summary: "Some data is locked by iOS. Here are the alternatives that work.",
            steps: [
                GuideStep(
                    title: "Messages and WhatsApp",
                    text: "iOS doesn't let apps read SMS, iMessage or chats. WhatsApp has its own transfer: Settings, Chats, Transfer chats, or follow its steps while setting up the new phone. Telegram and Viber keep chats in the cloud.",
                    illustration: .permissionAccess
                ),
                GuideStep(
                    title: "Passwords",
                    text: "Apps can't read saved passwords. Export them on a computer, e.g. on a Mac in the Passwords app with File, Export, then import them into Google Password Manager. Or use a cross-platform password manager.",
                    illustration: .stepSettings
                ),
                GuideStep(
                    title: "Contacts and calendars in iCloud",
                    text: "Instead of copying you can sync: add your Google account on the iPhone in Settings and turn on Contacts and Calendars. They appear on Android automatically.",
                    illustration: .contacts
                ),
                GuideStep(
                    title: "Apps and purchases",
                    text: "Apps and in-app purchases are tied to the App Store. Install the Android versions from Google Play and sign in. Health data, Wallet cards and alarms stay on iOS.",
                    illustration: .transferDevices
                ),
                GuideStep(
                    title: "Notes, music and iCloud Drive",
                    text: "Notes can sync with your Google account or be shared as files. Music services keep your library online. Download files from iCloud Drive in the Files app and send them as files.",
                    illustration: .files,
                    action: GuideStepAction(
                        title: "Send files",
                        systemImage: "arrow.up.circle",
                        kind: .transfer(.send(nil))
                    )
                ),
            ],
            transferStart: nil
        )
    }
}

// MARK: - FAQ

private extension GuideLibrary {
    static var faq: Guide {
        Guide(
            id: .faq,
            summary: "Short answers to the most common questions about transferring data.",
            steps: [],
            faq: [
                GuideFAQItem(
                    question: "Is data deleted from the old phone?",
                    answer: "No. The app only reads your data and makes copies. Nothing is deleted or changed on the old phone.",
                    requiresPremium: false
                ),
                GuideFAQItem(
                    question: "Do I need to keep the app open?",
                    answer: "Yes. iOS pauses apps in the background, so keep the app on screen until the transfer ends. The screen stays on automatically."
                ),
                GuideFAQItem(
                    question: "How long does it take?",
                    answer: "Contacts and calendars take seconds. Photos and videos depend on their size: about 1 GB per minute over good Wi-Fi. The connection check shows an estimate."
                ),
                GuideFAQItem(
                    question: "Do I need Wi-Fi or internet?",
                    answer: "Both devices need the same Wi-Fi network or one phone's Personal Hotspot. Internet access isn't required and mobile data isn't used for the transfer."
                ),
                GuideFAQItem(
                    question: "Is it secure?",
                    answer: "Data goes directly between your devices on your local network and is never uploaded to a cloud. Browser transfers use a one-time link that you confirm on the iPhone. Only share the link with the device you want to connect."
                ),
                GuideFAQItem(
                    question: "Which Android phones are supported?",
                    answer: "Any Android phone with a modern browser, e.g. Samsung Galaxy, Google Pixel, Xiaomi, OnePlus and others. No app is needed on Android."
                ),
                GuideFAQItem(
                    question: "What can't be transferred?",
                    answer: "iOS doesn't allow apps to copy messages, apps, passwords and some settings. The guide “What iOS can't transfer” lists the alternatives."
                ),
            ],
            transferStart: nil
        )
    }
}
