import Foundation
import Combine

/// Позволяет управлять онбордингом извне: переходить к следующему шагу, пропускать пейвол
/// и выбирать продукт покупки для кастомного UI продуктов
@MainActor
public final class OnboardingController: ObservableObject {
    /// Продукты текущего шага (с учётом hiddenProductIDs / secondaryHiddenProductIDs)
    @Published public private(set) var products: [PremiumProduct] = []
    
    /// id продукта, который сейчас выбран и будет куплен по кнопке Continue
    @Published public private(set) var selectedProductID: String?
    
    var onNext: (() -> Void)?
    var onSkip: (() -> Void)?
    private var onProductSelect: ((String) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {}
    
    public func next() {
        onNext?()
    }

    /// Выполняет штатный пропуск без покупки: callback текущего пейвола,
    /// тактильный отклик, запрос оценки согласно настройкам и завершение онбординга.
    public func skip() {
        onSkip?()
    }
    
    /// Выбирает продукт с заданным id: он остаётся выбранным, и покупается именно он
    public func select(productID: String) {
        onProductSelect?(productID)
    }
    
    /// Выбирает продукт: он остаётся выбранным, и покупается именно он
    public func select(_ product: PremiumProduct) {
        select(productID: product.id)
    }
    
    func attach(viewModel: OnboardingBuilderViewModel) {
        onProductSelect = { [weak viewModel] productID in
            viewModel?.select(productID: productID)
        }
        cancellables.removeAll()
        syncState(with: viewModel)
        viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak viewModel] _ in
                guard let self, let viewModel else { return }
                self.syncState(with: viewModel)
            }
            .store(in: &cancellables)
    }
    
    private func syncState(with viewModel: OnboardingBuilderViewModel) {
        let newProducts = viewModel.products
        if newProducts != products {
            products = newProducts
        }
        let newSelectedID = viewModel.selectedProduct?.id
        if newSelectedID != selectedProductID {
            selectedProductID = newSelectedID
        }
    }
}
