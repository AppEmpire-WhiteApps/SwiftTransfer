import PremiumKit
import SwiftData
import SwiftUI

@main
struct SwiftTransferApp: App {
    @UIApplicationDelegateAdaptor(PremiumAppDelegate.self) private var appDelegate
    @State private var router = AppRouter()
    @State private var activity = AppActivityContext()

    init() {
        PremiumSetup.configureIfReady()
        ExportService.removeTemporaryFiles()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(activity)
                .preferredColorScheme(.light)
                .tint(AppColor.primary)
        }
        .modelContainer(for: [TransferRecord.self, ChatThread.self, ChatMessage.self])
    }

}
