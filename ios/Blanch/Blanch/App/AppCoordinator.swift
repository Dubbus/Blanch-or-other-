import SwiftUI

// MARK: - Coordinator Protocol
// OOP Pattern: Protocol (Interface)
// Defines a contract that all coordinators must follow.
// Enables polymorphism — any coordinator can be used interchangeably.

protocol CoordinatorProtocol: AnyObject {
    associatedtype ContentView: View
    func start() -> ContentView
}

// MARK: - App Coordinator
// OOP Pattern: Coordinator + Composition
// The root coordinator owns child coordinators and manages top-level navigation.
// Composition over inheritance — AppCoordinator doesn't subclass anything,
// it OWNS other coordinators as properties.

@MainActor
final class AppCoordinator: ObservableObject {
    // Dependencies — injected into child coordinators
    private let networkClient: NetworkClientProtocol
    private let authManager: AuthManager
    private let viewModelFactory: ViewModelFactory

    init() {
        let client = NetworkClient(baseURL: "http://localhost:8001/api/v1")
        self.networkClient = client
        self.authManager = AuthManager.shared
        self.viewModelFactory = ViewModelFactory(
            networkClient: client,
            authManager: AuthManager.shared
        )
    }

    @ViewBuilder
    func rootView() -> some View {
        TabView {
            Tab("Discover", systemImage: "sparkle.magnifyingglass") {
                productListView()
            }
            Tab("Influencers", systemImage: "person.2.fill") {
                InfluencerListView(
                    viewModel: self.viewModelFactory.makeInfluencerListViewModel()
                )
            }
            Tab("Analyze", systemImage: "camera.fill") {
                AnalysisView(
                    viewModel: self.viewModelFactory.makeAnalysisViewModel()
                )
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                ProfilePlaceholderView()
            }
        }
        .tint(Color("AccentWarm", bundle: nil))
    }

    private func productListView() -> some View {
        ProductListView(
            viewModel: self.viewModelFactory.makeProductListViewModel(),
            viewModelFactory: self.viewModelFactory
        )
    }
}

// MARK: - Placeholder Views (temporary)

struct ProfilePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Profile")
                .font(.title2.weight(.semibold))
            Text("Sign in to save your results")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
