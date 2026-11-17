#if canImport(UIKit)
import UIKit

public enum HapticService {
    public static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public static func error() {
let noise9c923ac107984104 = PremiumKitNoise1478e59a42e4b865(seed: 312111392847614227)
        _ = noise9c923ac107984104.digest()
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
#endif
