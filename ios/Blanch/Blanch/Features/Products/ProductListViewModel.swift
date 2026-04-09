import Foundation

// MARK: - Product List ViewModel
// OOP Patterns: Inheritance (extends BaseViewModel) + Strategy (optional recommendation strategy)
//
// Inherits from BaseViewModel:
// - Gets isLoading, errorMessage, hasLoaded for free
// - Overrides fetchData() (Template Method) with product-specific logic
//
// Optionally uses a RecommendationStrategy:
// - If a strategy is injected, uses it to get personalized recommendations
// - If no strategy, fetches all products with optional filters

@MainActor
final class ProductListViewModel: BaseViewModel {
    @Published var products: [ProductDTO] = []
    @Published var total: Int = 0
    @Published var searchQuery: String = ""
    @Published var selectedCategory: String?

    private let repository: ProductRepositoryProtocol
    private let strategy: RecommendationStrategy?

    // Dependency injection via init — the ViewModel doesn't create its own dependencies
    init(repository: ProductRepositoryProtocol, strategy: RecommendationStrategy? = nil) {
        self.repository = repository
        self.strategy = strategy
    }

    // Template Method: this is the "blank" that BaseViewModel.loadData() calls
    override func fetchData() async throws {
        if let strategy {
            // Strategy pattern: delegate to the injected strategy
            products = try await strategy.getRecommendations(limit: 50)
            total = products.count
        } else if !searchQuery.isEmpty {
            let response = try await repository.searchProducts(query: searchQuery, limit: 50, offset: 0)
            products = response.products
            total = response.total
        } else {
            let response = try await repository.getProducts(
                category: selectedCategory,
                retailer: nil,
                seasonId: nil,
                limit: 50,
                offset: 0
            )
            products = response.products
            total = response.total
        }
    }

    func search() async {
        await loadData()
    }

    func filterByCategory(_ category: String?) async {
        selectedCategory = category
        await loadData()
    }
}
