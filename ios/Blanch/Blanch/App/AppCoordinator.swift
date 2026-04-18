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
        let client = NetworkClient(baseURL: "https://blanch-api.onrender.com/api/v1")
        self.networkClient = client
        self.authManager = AuthManager.shared
        self.viewModelFactory = ViewModelFactory(
            networkClient: client,
            authManager: AuthManager.shared,
            userSession: UserSession()
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
            Tab("Quiz", systemImage: "checklist") {
                questionnaireHostView()
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                profileTab()
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

    private func questionnaireHostView() -> some View {
        let trio = viewModelFactory.makeQuestionnaireHost()
        return QuestionnaireHostView(
            shared: trio.shared,
            stage1VM: trio.stage1,
            drapingVM: trio.draping
        )
    }

    @ViewBuilder
    private func profileTab() -> some View {
        NavigationStack {
            ProfileGate(
                authManager: authManager,
                session: viewModelFactory.userSession,
                viewModelFactory: viewModelFactory
            )
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Profile Gate
//
// Switches between SignInView (logged out) and ProfileView (logged in)
// based on AuthManager state. Observes AuthManager so it updates
// reactively when the user logs in or out.

private struct ProfileGate: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var session: UserSession
    let viewModelFactory: ViewModelFactory

    var body: some View {
        if authManager.isAuthenticated {
            ProfileView(authManager: authManager, session: session)
        } else {
            SignInView(viewModel: viewModelFactory.makeAuthViewModel())
        }
    }
}
