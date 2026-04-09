import Foundation

// MARK: - Product Repository
// OOP Pattern: Repository
//
// Concrete implementation of ProductRepositoryProtocol.
// Talks to the Blanch API via NetworkClient + RequestBuilder.
// The ViewModel only sees the protocol — it doesn't know this class exists.

final class ProductRepository: ProductRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String

    init(networkClient: NetworkClientProtocol, baseURL: String) {
        self.networkClient = networkClient
        self.baseURL = baseURL
    }

    func getProducts(
        category: String? = nil,
        retailer: String? = nil,
        seasonId: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> ProductListResponse {
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.products)
            .addQuery("category", category)
            .addQuery("retailer", retailer)
            .addQuery("season_id", seasonId)
            .addQuery("limit", String(limit))
            .addQuery("offset", String(offset))
            .build()

        return try await networkClient.request(request)
    }

    func searchProducts(query: String, limit: Int = 50, offset: Int = 0) async throws -> ProductListResponse {
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.productSearch)
            .addQuery("q", query)
            .addQuery("limit", String(limit))
            .addQuery("offset", String(offset))
            .build()

        return try await networkClient.request(request)
    }

    func getProduct(id: String) async throws -> ProductWithSeasons {
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.product(id))
            .build()

        return try await networkClient.request(request)
    }
}
