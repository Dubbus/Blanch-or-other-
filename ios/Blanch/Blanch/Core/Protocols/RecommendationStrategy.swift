import Foundation

// MARK: - Recommendation Strategy
// OOP Pattern: Strategy
//
// The Strategy pattern defines a family of algorithms (recommendation methods),
// encapsulates each one in its own class, and makes them interchangeable.
//
// The ProductListViewModel doesn't know WHICH recommendation algorithm is being used —
// it just calls strategy.getRecommendations(). At runtime, we can inject:
// - SeasonBasedStrategy: products matching the user's color season
// - InfluencerBasedStrategy: products endorsed by followed influencers
// - PopularityStrategy: most-mentioned products across all influencers
//
// New strategies can be added without modifying existing code (Open/Closed Principle).

protocol RecommendationStrategy: AnyObject, Sendable {
    var name: String { get }
    func getRecommendations(limit: Int) async throws -> [ProductDTO]
}
