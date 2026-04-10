import Foundation

// MARK: - Season-Based Recommendation Strategy
// OOP Pattern: Strategy (concrete implementation)
//
// One of several interchangeable algorithms for recommending products.
// This one filters products by the user's color season.
// The ViewModel doesn't know which strategy it's using — it just calls
// strategy.getRecommendations().

final class SeasonBasedStrategy: RecommendationStrategy, Sendable {
    let name = "For Your Season"

    private let seasonId: String
    private let repository: ProductRepositoryProtocol

    init(seasonId: String, repository: ProductRepositoryProtocol) {
        self.seasonId = seasonId
        self.repository = repository
    }

    func getRecommendations(limit: Int = 20) async throws -> [ProductDTO] {
        let response = try await repository.getProducts(
            category: nil,
            brand: nil,
            retailer: nil,
            seasonId: seasonId,
            limit: limit,
            offset: 0
        )
        return response.products
    }
}
