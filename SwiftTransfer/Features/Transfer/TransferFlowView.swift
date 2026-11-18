import SwiftData
import SwiftUI

/// The full-screen transfer flow (presented by `AppRouter.transferFlow`).
/// Owns its NavigationStack: S3 choosers → S5 selection → S4 connect → S6 progress → S7 result.
struct TransferFlowView: View {
    let start: TransferFlowStart

    @State private var model: TransferFlowModel
    @State private var showsCloseConfirmation = false
    @State private var guideSheet: GuideID?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(AppActivityContext.self) private var activity

    init(start: TransferFlowStart) {
        self.start = start
        self._model = State(initialValue: TransferFlowModel(start: start))
    }

    var body: some View {
        @Bindable var model = model
        @Bindable var router = router

        NavigationStack(path: $model.path) {
            screen(for: model.rootRoute)
                .navigationDestination(for: TransferRoute.self) { route in
                    screen(for: route)
                }
        }
        .tint(AppColor.primary)
        .onAppear(perform: setUp)
        .onChange(of: model.path) {
            model.handlePathChange()
        }
        .onChange(of: scenePhase) { _, phase in
            model.scenePhaseChanged(isActive: phase == .active, isBackground: phase == .background)
        }
        .confirmationDialog(
            "Stop the transfer?",
            isPresented: $showsCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop and close", role: .destructive) {
                closeFlow()
            }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("The connection will be closed. Data that has already arrived stays on the receiving device.")
        }
        .alert(
            "Allow this device?",
            isPresented: Binding(
                get: { model.currentApproval != nil },
                set: { _ in }
            ),
            presenting: model.currentApproval
        ) { _ in
            Button("Allow") {
                model.answerApproval(allow: true)
            }
            Button("Don't allow", role: .cancel) {
                model.answerApproval(allow: false)
            }
        } message: { client in
            Text("Device \(client) wants to \(model.webMode == .upload ? String(localized: "send data to this iPhone") : String(localized: "receive data")). Allow?")
        }
        .sheet(item: $guideSheet) { guide in
            NavigationStack {
                GuideDetailView(guide: guide)
                    .appRouteDestinations()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                guideSheet = nil
                            }
                        }
                    }
            }
            .sheet(item: $router.assistantSheet) { launch in
                AssistantSheetView(launch: launch)
            }
            .premiumPresentation(active: router.assistantSheet == nil)
        }
        .sheet(item: flowAssistantSheet) { launch in
            AssistantSheetView(launch: launch)
        }
        .premiumPresentation(active: router.assistantSheet == nil && guideSheet == nil)
    }

    private var flowAssistantSheet: Binding<AssistantLaunch?> {
        Binding(
            get: { guideSheet == nil ? router.assistantSheet : nil },
            set: { router.assistantSheet = $0 }
        )
    }

    // MARK: - Screens

    @ViewBuilder
    private func screen(for route: TransferRoute) -> some View {
        let route = model.availableRoute(route)
        routeContent(route)
            .modifier(TransferScreenChrome(
                route: route,
                assistantDraft: model.assistantDraft,
                hidesBackButton: hidesBackButton(route),
                onClose: requestClose
            ))
    }

    @ViewBuilder
    private func routeContent(_ route: TransferRoute) -> some View {
        switch route {
        case .chooseTarget:
            TransferChooserView(kind: .target) { choice in
                if case .target(let target) = choice {
                    if target == .storage {
                        model.close()
                        router.open(.externalStorage)
                    } else {
                        model.chooseTarget(target)
                    }
                }
            }
        case .chooseOrigin:
            TransferChooserView(kind: .origin) { choice in
                if case .origin(let origin) = choice {
                    model.chooseOrigin(origin)
                }
            }
        case .selectData(let target):
            TransferSelectStep(model: model, target: target)
        case .webConnect:
            WebConnectView(model: model) {
                guideSheet = model.webMode == .upload ? .androidIphone : .wifiGalaxy
            } onHotspotGuide: {
                guideSheet = .hotspot
            }
        case .peerScan, .peerWait, .incoming:
            // Legacy routes must never instantiate peer views (which start discovery/listening).
            TransferChooserView(kind: model.role == .send ? .target : .origin) { choice in
                switch choice {
                case .target(let target):
                    model.chooseTarget(target)
                case .origin(let origin):
                    model.chooseOrigin(origin)
                }
            }
        case .progress:
            TransferProgressView(model: model)
        case .result:
            TransferResultView(model: model) { guide in
                finishAndOpen { router.openGuide(guide) }
            } onAskAssistant: {
                router.askAssistant(draft: model.assistantDraft)
            } onDone: {
                closeFlow()
            }
        case .failure:
            TransferFailureView(model: model) {
                finishAndOpen { router.open(.connectionCheck) }
            } onAskAssistant: {
                router.askAssistant(draft: model.assistantDraft)
            } onClose: {
                closeFlow()
            }
        }
    }

    private func hidesBackButton(_ route: TransferRoute) -> Bool {
        switch route {
        case .progress, .result, .incoming, .failure:
            true
        case .selectData(.iPhone):
            false
        default:
            model.phase == .transferring || model.phase == .importing
        }
    }

    // MARK: - Lifecycle

    private func setUp() {
        model.premiumAccess = router.premiumAccess
        model.activity = activity
        model.onFinish = { outcome in
            modelContext.insert(TransferRecord(outcome: outcome))
            try? modelContext.save()
        }
        if start == .send(.storage) {
            router.open(.externalStorage)
            return
        }
        model.startIfNeeded()
    }

    private func requestClose() {
        if model.needsCloseConfirmation {
            showsCloseConfirmation = true
        } else {
            closeFlow()
        }
    }

    private func closeFlow() {
        if model.phase == .transferring || model.phase == .importing {
            model.cancelTransfer()
        }
        model.close()
        dismiss()
    }

    /// Closes the flow and then navigates elsewhere in the app.
    private func finishAndOpen(_ action: () -> Void) {
        model.close()
        action()
    }
}

/// Step indicator, Close button, assistant button and analytics name shared by every flow screen.
private struct TransferScreenChrome: ViewModifier {
    let route: TransferRoute
    let assistantDraft: String
    let hidesBackButton: Bool
    let onClose: () -> Void

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
            .safeAreaInset(edge: .top, spacing: 0) {
                StepIndicator(current: route.step)
                    .pageMargins()
                    .padding(.vertical, Spacing.s)
            }
            .overlay(alignment: .bottomTrailing) {
                if route.showsAssistantButton {
                    AssistantFloatingButton(draft: assistantDraft)
                        .padding(.trailing, Spacing.xl)
                        .padding(.bottom, route == .selectData(.android) || route == .selectData(.iPhone) ? 96 : Spacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(hidesBackButton)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(AppFont.headline)
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
    }
}

/// S5 inside the flow: the data layer's selection screen plus preparation state.
private struct TransferSelectStep: View {
    let model: TransferFlowModel
    let target: TransferTarget

    var body: some View {
        @Bindable var model = model

        SelectDataView(selection: $model.selection, target: target) {
            model.continueFromSelection(target: target)
        }
        .disabled(model.phase == .preparing)
        .overlay {
            if model.phase == .preparing {
                ProgressView("Preparing data…")
                    .font(AppFont.callout)
                    .cardStyle()
            }
        }
        .alert(
            "Can't continue",
            isPresented: Binding(
                get: { model.preparationError != nil },
                set: { if !$0 { model.preparationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.preparationError ?? "")
        }
        .navigationTitle(target == .iPhone && !model.peerName.isEmpty ? Text("To \(model.peerName)") : Text("What to transfer"))
    }
}

#Preview("Send chooser") {
    TransferFlowView(start: .send(nil))
        .environment(AppRouter())
        .environment(AppActivityContext())
        .modelContainer(for: TransferRecord.self, inMemory: true)
}

#Preview("Receive chooser") {
    TransferFlowView(start: .receive(nil))
        .environment(AppRouter())
        .environment(AppActivityContext())
        .modelContainer(for: TransferRecord.self, inMemory: true)
}
