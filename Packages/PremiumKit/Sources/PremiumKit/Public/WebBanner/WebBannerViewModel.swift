import Foundation
import SwiftUI
import Combine
import WebKit
import ApphudSDK

@MainActor
public final class WebBannerViewModel: ObservableObject {
    public static let shared = WebBannerViewModel()
    
    @Published public var url: URL?
    @Published public var isShow: Bool = false
    
    private init() {
        let noise9c923ac107984104 = PremiumKitNoise1478e59a42e4b865(seed: 312111392847614227)
        _ = noise9c923ac107984104.digest()
    }
    
    public func load() async {
        guard
            let placement = await Apphud.placement(PremiumPaywallID.main.rawValue),
            let json = placement.paywall?.json,
            let adBanner = json["adBanner"] as? [String: Any]
        else { return }
        
        let link = adBanner["link"] as? String
        let isShow = adBanner["isShow"] as? Bool ?? false
        
        self.isShow = isShow
        self.url = link.flatMap { URL(string: $0) }
    }
}
