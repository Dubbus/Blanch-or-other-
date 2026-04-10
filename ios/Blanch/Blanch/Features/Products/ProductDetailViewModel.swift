import Foundation

@MainActor
final class ProductDetailViewModel: BaseViewModel {
    @Published var product: ProductWithSeasons?
    @Published var siblingShades: [ProductDTO] = []

    private let productId: String
    private let repository: ProductRepositoryProtocol

    init(productId: String, repository: ProductRepositoryProtocol) {
        self.productId = productId
        self.repository = repository
    }

    override func fetchData() async throws {
        async let productFetch = repository.getProduct(id: productId)
        async let shadesFetch = repository.getSiblingShades(productId: productId)

        let (p, s) = try await (productFetch, shadesFetch)
        product = p
        siblingShades = s
    }

    func switchToShade(_ shade: ProductDTO) {
        // Reload with the new shade's ID
        let vm = ProductDetailViewModel(productId: shade.id, repository: repository)
        Task {
            await vm.loadData()
            self.product = vm.product
            self.siblingShades = vm.siblingShades
        }
    }
}
