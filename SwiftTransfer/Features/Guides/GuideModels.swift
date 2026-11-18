import Foundation
import SwiftUI

/// A built-in step-by-step guide. Content lives in `GuideLibrary` as localizable Swift literals
/// (replaces `Resources/Guides/guides.json` from the TZ so the strings land in the String Catalog).
struct Guide: Identifiable, Sendable {
    let id: GuideID
    let summary: LocalizedStringResource
    let steps: [GuideStep]
    /// Accordion answers (used by the FAQ guide).
    var faq: [GuideFAQItem] = []
    /// Where "Start transfer" on the last step leads; nil hides the button.
    var transferStart: TransferFlowStart?

    var title: LocalizedStringResource { id.title }
    var cover: Illustration { id.cover }
    var minutes: Int { id.minutes }

    /// Guides with phases show the Launch → Connect → Select → Transfer indicator.
    var showsPhases: Bool {
        steps.contains { $0.phase != nil }
    }

    /// Every illustration the guide uses (cover and steps).
    var illustrations: [Illustration] {
        [cover] + steps.map(\.illustration)
    }
}

/// One page of a guide.
struct GuideStep: Identifiable, Sendable {
    let id = UUID()
    let title: LocalizedStringResource
    let text: LocalizedStringResource
    let illustration: Illustration
    var phase: StepIndicator.Step?
    var action: GuideStepAction?
}

/// Optional button on a guide step.
struct GuideStepAction: Sendable {
    enum Kind: Sendable, Hashable {
        /// Pushed onto the current navigation stack.
        case route(AppRoute)
        case transfer(TransferFlowStart)
        case assistant(AssistantAction)
    }

    let title: LocalizedStringResource
    let systemImage: String
    let kind: Kind

    static func guide(_ guide: GuideID, title: LocalizedStringResource) -> GuideStepAction {
        GuideStepAction(title: title, systemImage: "book", kind: .route(.guide(guide)))
    }

    static func route(_ route: AppRoute, title: LocalizedStringResource, systemImage: String) -> GuideStepAction {
        GuideStepAction(title: title, systemImage: systemImage, kind: .route(route))
    }

    static func action(_ action: AssistantAction) -> GuideStepAction {
        GuideStepAction(title: action.title, systemImage: action.systemImage, kind: .assistant(action))
    }
}

/// A question with an expandable answer.
struct GuideFAQItem: Identifiable, Sendable {
    let id = UUID()
    let question: LocalizedStringResource
    let answer: LocalizedStringResource
}
