import Foundation

@MainActor
final class InfluencerListViewModel: BaseViewModel {
    @Published var influencers: [InfluencerDTO] = []
    @Published var total: Int = 0

    private let repository: InfluencerRepositoryProtocol

    init(repository: InfluencerRepositoryProtocol) {
        self.repository = repository
    }

    override func fetchData() async throws {
        let response = try await repository.getInfluencers(seasonId: nil, platform: nil, limit: 50, offset: 0)
        influencers = response.influencers
        total = response.total
    }
}
