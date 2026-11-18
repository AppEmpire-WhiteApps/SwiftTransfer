import SwiftUI

/// All generated PNG illustrations bundled in Assets.xcassets/Illustrations.
enum Illustration: String, CaseIterable {
    case appLogo = "app_logo"
    case onbTransfer = "onb_transfer"
    case onbDataTypes = "onb_data_types"
    case onbSecure = "onb_secure"
    case heroPhones = "hero_phones"
    case contacts = "ic3d_contacts"
    case calendar = "ic3d_calendar"
    case reminders = "ic3d_reminders"
    case photos = "ic3d_photos"
    case videos = "ic3d_videos"
    case files = "ic3d_files"
    case methodWifi = "method_wifi"
    case methodCable = "method_cable"
    case methodIphone = "method_iphone"
    case deviceAndroid = "device_android"
    case deviceIphone = "device_iphone"
    case deviceStorage = "device_storage"
    case connectSearching = "connect_searching"
    case connectQR = "connect_qr"
    case connectHotspot = "connect_hotspot"
    case transferDevices = "transfer_devices"
    case success = "success"
    case partialSuccess = "partial_success"
    case errorConnection = "error_connection"
    case permissionAccess = "permission_access"
    case storageDrive = "storage_drive"
    case connectionCheck = "connection_check"
    case assistantAvatar = "assistant_avatar"
    case assistantEmpty = "assistant_empty"
    case emptyHistory = "empty_history"
    case guideWifiGalaxy = "guide_wifi_galaxy"
    case guideCableGalaxy = "guide_cable_galaxy"
    case guideStorage = "guide_storage"
    case guideIphoneIphone = "guide_iphone_iphone"
    case guideAndroidIphone = "guide_android_iphone"
    case guideHotspot = "guide_hotspot"
    case guideImportSamsung = "guide_import_samsung"
    case guideNotTransferable = "guide_not_transferable"
    case guideFAQ = "guide_faq"
    case stepTrust = "step_trust"
    case stepSelect = "step_select"
    case stepProgress = "step_progress"
    case stepFiles = "step_files"
    case stepSettings = "step_settings"

    var image: Image {
        Image(rawValue)
    }
}

/// Renders a PNG illustration with an optional soft glow and gentle floating motion.
struct IllustrationView: View {
    let illustration: Illustration
    var height: CGFloat = 200
    var glow: Bool = true
    var floating: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isUp = false

    var body: some View {
        ZStack {
            if glow {
                Circle()
                    .fill(AppGradient.glow(radius: height * 0.6))
                    .frame(width: height * 1.2, height: height * 1.2)
            }
            illustration.image
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: height)
                .offset(y: floating && !reduceMotion ? (isUp ? -6 : 6) : 0)
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .onAppear {
            guard floating, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isUp = true
            }
        }
    }
}
