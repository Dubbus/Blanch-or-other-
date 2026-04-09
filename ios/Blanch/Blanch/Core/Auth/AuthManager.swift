import Foundation
import Combine

// MARK: - Auth Manager
// OOP Pattern: Singleton
//
// Singleton ensures exactly ONE instance of AuthManager exists app-wide.
// Every ViewModel, Repository, and Coordinator accesses the same auth state
// via AuthManager.shared.
//
// Why Singleton here:
// - Auth state (logged-in user, JWT token) is truly global — there's one user session
// - Multiple instances would cause state conflicts (one logs in, another doesn't know)
// - Singleton provides a single source of truth for auth

@MainActor
final class AuthManager: ObservableObject, Sendable {
    // The single shared instance
    static let shared = AuthManager()

    @Published var currentUser: UserDTO?
    @Published var isAuthenticated = false

    private var token: String?

    // Private init prevents creating additional instances
    private init() {
        // Load token from UserDefaults on launch
        // (In production, use Keychain via KeychainService)
        self.token = UserDefaults.standard.string(forKey: "auth_token")
        self.isAuthenticated = token != nil
    }

    var accessToken: String? { token }

    func setSession(token: String, user: UserDTO) {
        self.token = token
        self.currentUser = user
        self.isAuthenticated = true
        UserDefaults.standard.set(token, forKey: "auth_token")
    }

    func logout() {
        self.token = nil
        self.currentUser = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }

    var isPremium: Bool {
        currentUser?.subscriptionTier == "premium"
    }
}
