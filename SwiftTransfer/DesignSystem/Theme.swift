import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

/// Color tokens of the light blue-and-white design system.
enum AppColor {
    static let primary = Color(hex: 0x1E6BFF)
    static let primaryPressed = Color(hex: 0x1557D6)
    static let primaryDeep = Color(hex: 0x0B3D91)
    static let sky = Color(hex: 0x4FA3FF)
    static let skyLight = Color(hex: 0xD9ECFF)
    static let skyMist = Color(hex: 0xEEF6FF)
    static let background = Color(hex: 0xF6F9FE)
    static let surface = Color.white
    static let textPrimary = Color(hex: 0x0E1A2B)
    static let textSecondary = Color(hex: 0x52627A)
    static let textTertiary = Color(hex: 0x8C98AC)
    static let divider = Color(hex: 0xE3EAF5)
    static let success = Color(hex: 0x16B67F)
    static let warning = Color(hex: 0xF5A524)
    static let error = Color(hex: 0xE5484D)
}

enum AppGradient {
    static let hero = LinearGradient(
        colors: [Color(hex: 0xEAF4FF), Color.white],
        startPoint: .top,
        endPoint: .bottom
    )

    static let primary = LinearGradient(
        colors: [AppColor.primary, AppColor.sky],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screen = LinearGradient(
        colors: [Color(hex: 0xEAF4FF), AppColor.background, AppColor.background],
        startPoint: .top,
        endPoint: .bottom
    )

    static func glow(radius: CGFloat) -> RadialGradient {
        RadialGradient(
            colors: [AppColor.sky.opacity(0.28), AppColor.sky.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: radius
        )
    }
}

enum AppFont {
    static let display = Font.largeTitle.weight(.bold)
    static let title1 = Font.title.weight(.bold)
    static let title2 = Font.title2.weight(.semibold)
    static let headline = Font.headline
    static let body = Font.body
    static let callout = Font.callout
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let metric = Font.system(size: 48, weight: .bold, design: .rounded).monospacedDigit()
}

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 24
    static let button: CGFloat = 16
    static let field: CGFloat = 14
    static let small: CGFloat = 12
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = Spacing.l
    var background: Color = AppColor.surface

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .shadow(color: AppColor.primary.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}

extension View {
    func cardStyle(padding: CGFloat = Spacing.l, background: Color = AppColor.surface) -> some View {
        modifier(CardStyle(padding: padding, background: background))
    }

    /// Standard screen background: soft blue fade into the light background.
    func screenBackground() -> some View {
        background(AppGradient.screen.ignoresSafeArea())
    }

    /// Horizontal page margins: 20 on compact width, 32 on regular width.
    func pageMargins() -> some View {
        modifier(PageMargins())
    }
}

private struct PageMargins: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content.padding(.horizontal, sizeClass == .regular ? Spacing.xxxl : Spacing.xl)
    }
}
