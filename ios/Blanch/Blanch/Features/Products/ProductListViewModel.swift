import Foundation

// MARK: - Product List ViewModel
// OOP Patterns: Inheritance (extends BaseViewModel) + Strategy (optional recommendation strategy)

@MainActor
final class ProductListViewModel: BaseViewModel {
    @Published var products: [ProductDTO] = []
    @Published var recommendedProducts: [ProductDTO] = []
    @Published var total: Int = 0
    @Published var searchQuery: String = ""
    @Published var selectedCategory: String?
    @Published var selectedBrand: String?
    @Published var brands: [String] = []
    @Published var userSeasonId: String?

    private let repository: ProductRepositoryProtocol
    private let strategy: RecommendationStrategy?

    init(repository: ProductRepositoryProtocol, strategy: RecommendationStrategy? = nil) {
        self.repository = repository
        self.strategy = strategy
    }

    override func fetchData() async throws {
        // Load brands on first fetch
        if brands.isEmpty {
            brands = try await repository.getBrands()
        }

        if let strategy {
            products = try await strategy.getRecommendations(limit: 50)
            total = products.count
        } else if !searchQuery.isEmpty {
            let response = try await repository.searchProducts(query: searchQuery, limit: 50, offset: 0)
            products = response.products
            total = response.total
        } else {
            let response = try await repository.getProducts(
                category: selectedCategory,
                brand: selectedBrand,
                retailer: nil,
                seasonId: nil,
                limit: 50,
                offset: 0
            )
            products = response.products
            total = response.total

            // Load recommended products if user has a season
            if let seasonId = userSeasonId {
                let recResponse = try await repository.getProducts(
                    category: selectedCategory,
                    brand: selectedBrand,
                    retailer: nil,
                    seasonId: seasonId,
                    limit: 10,
                    offset: 0
                )
                recommendedProducts = recResponse.products
            }
        }
    }

    func search() async {
        await loadData()
    }

    func filterByCategory(_ category: String?) async {
        selectedCategory = category
        await loadData()
    }

    func filterByBrand(_ brand: String?) async {
        selectedBrand = brand
        await loadData()
    }
}
