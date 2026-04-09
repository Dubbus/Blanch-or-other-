import Foundation

struct UserDTO: Codable, Identifiable {
    let id: String
    let displayName: String
    let email: String
    let avatarUrl: String?
    let subscriptionTier: String
    let createdAt: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let user: UserDTO
}

struct RegisterRequest: Codable {
    let email: String
    let displayName: String
    let password: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}
