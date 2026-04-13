import Foundation

// MARK: - ViewModel Factory
// OOP Pattern: Factory
//
// The Factory pattern centralizes object creation.
// Instead of each View creating its own ViewModel (and needing to know
// about NetworkClient, AuthManager, Repositories, etc.), Views just ask
// the factory: "give me a ProductListViewModel."
//
// Why Factory here:
// - ViewModels need dependencies (repositories, auth, strategies)
// - Views shouldn't know about these dependencies
// - Factory encapsulates the wiring — change a dependency in ONE place
// - Makes dependency injection explicit and testable

@MainActor
final class ViewModelFactory {
    private let networkClient: NetworkClientProtocol
    private let authManager: AuthManager

    // Repositories (lazily created, shared across ViewModels)
    private lazy var productRepository: ProductRepository = {
        ProductRepository(networkClient: networkClient, baseURL: baseURL)
    }()

    private lazy var influencerRepository: InfluencerRepository = {
        InfluencerRepository(networkClient: networkClient, baseURL: baseURL)
    }()

    private lazy var analysisRepository: AnalysisRepository = {
        AnalysisRepository(networkClient: networkClient, baseURL: baseURL, authManager: authManager)
    }()

    private lazy var analysisPipeline: AnalysisPipeline = {
        AnalysisPipeline()
    }()

    private let baseURL: String

    init(networkClient: NetworkClientProtocol, authManager: AuthManager, baseURL: String = "http://localhost:8001/api/v1") {
        self.networkClient = networkClient
        self.authManager = authManager
        self.baseURL = baseURL
    }

    // MARK: - Product ViewModels

    func makeProductListViewModel() -> ProductListViewModel {
        ProductListViewModel(repository: productRepository)
    }

    func makeProductDetailViewModel(productId: String) -> ProductDetailViewModel {
        ProductDetailViewModel(productId: productId, repository: productRepository)
    }

    // MARK: - Influencer ViewModels

    func makeInfluencerListViewModel() -> InfluencerListViewModel {
        InfluencerListViewModel(repository: influencerRepository)
    }

    // MARK: - Analysis ViewModels

    func makeAnalysisViewModel() -> AnalysisViewModel {
        AnalysisViewModel(pipeline: analysisPipeline, repository: analysisRepository)
    }

    // MARK: - Strategy-based ViewModels

    func makeSeasonRecommendationViewModel(seasonId: String) -> ProductListViewModel {
        let strategy = SeasonBasedStrategy(
            seasonId: seasonId,
            repository: productRepository
        )
        return ProductListViewModel(repository: productRepository, strategy: strategy)
    }
}
