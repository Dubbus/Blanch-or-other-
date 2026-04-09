import Foundation

// MARK: - Influencer Repository
// OOP Pattern: Repository (concrete implementation)

final class InfluencerRepository: InfluencerRepositoryProtocol, Sendable {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String

    init(networkClient: NetworkClientProtocol, baseURL: String) {
        self.networkClient = networkClient
        self.baseURL = baseURL
    }

    func getInfluencers(
        seasonId: String? = nil,
        platform: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> InfluencerListResponse {
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.influencers)
            .addQuery("season_id", seasonId)
            .addQuery("platform", platform)
            .addQuery("limit", String(limit))
            .addQuery("offset", String(offset))
            .build()

        return try await networkClient.request(request)
    }

    func getInfluencer(id: String) async throws -> InfluencerDTO {
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.influencer(id))
            .build()

        return try await networkClient.request(request)
    }
}
