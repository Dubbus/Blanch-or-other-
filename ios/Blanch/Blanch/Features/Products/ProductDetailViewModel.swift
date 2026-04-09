import Foundation

@MainActor
final class ProductDetailViewModel: BaseViewModel {
    @Published var product: ProductWithSeasons?

    private let productId: String
    private let repository: ProductRepositoryProtocol

    init(productId: String, repository: ProductRepositoryProtocol) {
        self.productId = productId
        self.repository = repository
    }

    override func fetchData() async throws {
        product = try await repository.getProduct(id: productId)
    }
}
