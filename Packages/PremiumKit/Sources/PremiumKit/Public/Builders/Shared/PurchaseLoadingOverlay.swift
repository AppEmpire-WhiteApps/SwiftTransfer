import SwiftUI
import UIKit

extension View {
    /// Shows the purchase loader over the whole window, not only inside the builder's frame,
    /// so it is not clipped when the app places the builder in a narrower container.
    func purchaseLoadingOverlay(isLoading: Bool) -> some View {
        background(PurchaseLoadingWindowPresenter(isLoading: isLoading))
    }
}

private struct PurchaseLoadingView: View {
    var body: some View {
        BlurEffectView()
            .ignoresSafeArea()
            .overlay { ProgressView() }
    }
}

/// Invisible anchor view: takes the window scene from the builder and shows the loader
/// in a separate window above the app content while a purchase or restore is running.
private struct PurchaseLoadingWindowPresenter: UIViewRepresentable {
    let isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        let isLoading = isLoading
        // The window is not attached yet during the first update.
        DispatchQueue.main.async {
            coordinator.update(isLoading: isLoading, scene: uiView.window?.windowScene)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.hide()
    }

    @MainActor
    final class Coordinator {
        private static let fadeDuration: TimeInterval = 0.2

        private var window: UIWindow?

        func update(isLoading: Bool, scene: UIWindowScene?) {
            if isLoading {
                show(in: scene)
            } else {
                hide()
            }
        }

        func hide() {
            guard let window else { return }
            self.window = nil

            UIView.animate(withDuration: Self.fadeDuration) {
                window.alpha = 0
            } completion: { _ in
                window.isHidden = true
            }
        }

        private func show(in scene: UIWindowScene?) {
            guard window == nil, let scene else { return }

            let host = UIHostingController(rootView: PurchaseLoadingView())
            host.view.backgroundColor = .clear

            let window = UIWindow(windowScene: scene)
            window.windowLevel = .normal + 1
            window.backgroundColor = .clear
            window.rootViewController = host
            window.alpha = 0
            window.isHidden = false
            self.window = window

            UIView.animate(withDuration: Self.fadeDuration) {
                window.alpha = 1
            }
        }
    }
}
