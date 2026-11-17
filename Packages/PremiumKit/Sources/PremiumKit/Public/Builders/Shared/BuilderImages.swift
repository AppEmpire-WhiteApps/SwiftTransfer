import SwiftUI

/// Фоновые изображения билдера под разные устройства и состояния экрана.
/// Обязателен только `iphone`, незаданные варианты заменяются фоллбэком.
public struct AdaptiveResources: @unchecked Sendable {
    /// Обычный iPhone, Split View на iPhone Duo.
    public let iphone: Image
    /// iPhone SE / 8. Фоллбэк — `iphone`.
    public let iphoneS: Image
    /// iPad в портрете. Фоллбэк — `iphone`.
    public let ipad: Image
    /// iPad в ландшафте. Фоллбэк — `iphone`.
    public let ipadL: Image
    /// iPhone Duo сложен (внешний экран), любая ориентация. Фоллбэк — `iphone`.
    public let duoFolded: Image
    /// iPhone Duo разложен, вертикально. Фоллбэк — `ipad`.
    public let duoUnfolded: Image
    /// iPhone Duo разложен, горизонтально. Фоллбэк — `ipadL`.
    public let duoUnfoldedL: Image

    public init(
        iphone: Image,
        iphoneS: Image? = nil,
        ipad: Image? = nil,
        ipadL: Image? = nil,
        duoFolded: Image? = nil,
        duoUnfolded: Image? = nil,
        duoUnfoldedL: Image? = nil
    ) {
        let ipad = ipad ?? iphone
        let ipadL = ipadL ?? iphone
        self.iphone = iphone
        self.iphoneS = iphoneS ?? iphone
        self.ipad = ipad
        self.ipadL = ipadL
        self.duoFolded = duoFolded ?? iphone
        self.duoUnfolded = duoUnfolded ?? ipad
        self.duoUnfoldedL = duoUnfoldedL ?? ipadL
    }

    /// Картинка для типа экрана. Для незаданных вариантов уже подставлен фоллбэк.
    public func image(for screen: AdaptiveScreen) -> Image {
        switch screen {
        case .iphone:
            return iphone
        case .iphoneS:
            return iphoneS
        case .ipadPortrait:
            return ipad
        case .ipadLandscape:
            return ipadL
        case .duoFolded:
            return duoFolded
        case .duoUnfolded:
            return duoUnfolded
        case .duoUnfoldedLandscape:
            return duoUnfoldedL
        }
    }
}
