import SwiftUI

struct SplashView: View {
    var body: some View {
        Illustration.appLogo.image
            .resizable()
            .scaledToFit()
            .frame(width: 128, height: 128)
            .accessibilityLabel(Text(verbatim: "SwiftTransfer"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppGradient.hero.ignoresSafeArea())
    }
}
