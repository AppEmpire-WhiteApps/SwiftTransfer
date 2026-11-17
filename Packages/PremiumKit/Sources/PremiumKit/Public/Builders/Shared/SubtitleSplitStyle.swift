import SwiftUI

/// Разделение сабтайтла на две части: первые `splitBy` слов стилизуются как
/// «до» (beforeFont / beforeColor), остальной текст — как «после»
/// (afterFont / afterColor).
///
/// Используется как переопределение для конкретного экрана онбординга
/// (`OnboardingScreen.subtitleSplit`) или шага пейволла
/// (`OnboardingBuilder(paywallSubtitleSplit:)`): если задано, полностью заменяет
/// соответствующие значения из `OnboardingStyle`.
public struct SubtitleSplitStyle: Sendable {
    /// Количество первых слов, попадающих в часть «до»; nil — не разделять
    public var splitBy: Int?
    public var beforeFont: Font?
    public var beforeColor: Color?
    public var afterFont: Font?
    public var afterColor: Color?

    public init(
        splitBy: Int? = nil,
        beforeFont: Font? = nil,
        beforeColor: Color? = nil,
        afterFont: Font? = nil,
        afterColor: Color? = nil
    ) {
        self.splitBy = splitBy
        self.beforeFont = beforeFont
        self.beforeColor = beforeColor
        self.afterFont = afterFont
        self.afterColor = afterColor
    }
}
