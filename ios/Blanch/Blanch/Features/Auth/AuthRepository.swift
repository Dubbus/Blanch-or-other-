import Foundation

// MARK: - Auth Repository
// OOP Pattern: Repository
//
// Wraps the /auth/register and /auth/login endpoints. Returns an AuthResponse
// which the ViewModel hands to AuthManager.setSession(...) to persist the
// token and user. No dependency on AuthManager here — keeps the repository
// stateless so it stays easy to test.

protocol AuthRepositoryProtocol: AnyObject, Sendable {
    func register(email: String, displayName: String, password: String) async throws -> AuthResponse
    func login(email: String, password: String) async throws -> AuthResponse
}

final class AuthRepository: AuthRepositoryProtocol, Sendable {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String

    init(networkClient: NetworkClientProtocol, baseURL: String) {
        self.networkClient = networkClient
        self.baseURL = baseURL
    }

    func register(email: String, displayName: String, password: String) async throws -> AuthResponse {
        let body = RegisterRequest(email: email, displayName: displayName, password: password)
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.register)
            .setMethod("POST")
            .setBody(body)
            .build()
        return try await networkClient.request(request)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.login)
            .setMethod("POST")
            .setBody(body)
            .build()
        return try await networkClient.request(request)
    }
}
