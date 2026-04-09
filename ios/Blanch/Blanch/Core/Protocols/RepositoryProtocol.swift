import Foundation

// MARK: - Repository Protocol
// OOP Pattern: Repository + Protocol (Interface)
//
// The Repository pattern abstracts WHERE data comes from.
// The ViewModel doesn't know or care if data comes from the API, a local cache,
// or a mock — it just calls methods on the repository protocol.
//
// This enables:
// 1. Unit testing with mock repositories (no real API calls)
// 2. Adding offline/cache support later without changing ViewModels
// 3. Swapping data sources (e.g., API v1 → v2) transparently

protocol ProductRepositoryProtocol: AnyObject, Sendable {
    func getProducts(category: String?, retailer: String?, seasonId: String?, limit: Int, offset: Int) async throws -> ProductListResponse
    func searchProducts(query: String, limit: Int, offset: Int) async throws -> ProductListResponse
    func getProduct(id: String) async throws -> ProductWithSeasons
}

protocol InfluencerRepositoryProtocol: AnyObject, Sendable {
    func getInfluencers(seasonId: String?, platform: String?, limit: Int, offset: Int) async throws -> InfluencerListResponse
    func getInfluencer(id: String) async throws -> InfluencerDTO
}

protocol ComboRepositoryProtocol: AnyObject, Sendable {
    func getCombosForInfluencer(id: String, limit: Int, offset: Int) async throws -> LipComboListResponse
    func getCombo(id: String) async throws -> LipComboDTO
}

protocol SeasonRepositoryProtocol: AnyObject, Sendable {
    func getAllSeasons() async throws -> SeasonListResponse
    func getSeason(id: String) async throws -> SeasonDTO
}
