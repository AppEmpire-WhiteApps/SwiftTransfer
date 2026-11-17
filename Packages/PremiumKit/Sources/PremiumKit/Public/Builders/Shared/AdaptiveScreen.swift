import SwiftUI
import UIKit

/// Screen kind resolved from the window size and size classes instead of `UIScreen` / device orientation,
/// so iPhone Duo switches resources when it is folded, unfolded or rotated.
public enum AdaptiveScreen: Equatable, Sendable {
    case iphone
    case iphoneS
    case ipadPortrait
    case ipadLandscape
    case duoFolded
    case duoUnfolded
    case duoUnfoldedLandscape

    /// iPhone Duo outer display is ~466×678 pt (ratio ~0.69); regular iPhones are ~0.46, SE is ~0.56.
    private static let duoFoldedMinAspectRatio: CGFloat = 0.6
    private static let iphoneSMaxLongSide: CGFloat = 667

    public init(
        size: CGSize,
        horizontalSizeClass: UserInterfaceSizeClass?,
        verticalSizeClass: UserInterfaceSizeClass?
    ) {
        let isLandscape = size.width > size.height

        if UIDevice.isIpad {
            self = isLandscape ? .ipadLandscape : .ipadPortrait
            return
        }

        if horizontalSizeClass == .regular, verticalSizeClass == .regular {
            self = isLandscape ? .duoUnfoldedLandscape : .duoUnfolded
            return
        }

        let shortSide = min(size.width, size.height)
        let longSide = max(size.width, size.height)

        guard longSide > 0 else {
            self = .iphone
            return
        }

        if shortSide / longSide >= Self.duoFoldedMinAspectRatio {
            self = .duoFolded
        } else if longSide <= Self.iphoneSMaxLongSide {
            self = .iphoneS
        } else {
            self = .iphone
        }
    }
}
