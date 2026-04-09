import Foundation

// MARK: - API Endpoints
// Centralizes all API path definitions.
// Avoids string literals scattered across the codebase.

enum Endpoints {
    // Auth
    static let register = "/auth/register"
    static let login = "/auth/login"
    static let me = "/auth/me"

    // Seasons
    static let seasons = "/seasons"
    static func season(_ id: String) -> String { "/seasons/\(id)" }
    static func seasonProducts(_ id: String) -> String { "/seasons/\(id)/products" }
    static func seasonInfluencers(_ id: String) -> String { "/seasons/\(id)/influencers" }

    // Products
    static let products = "/products"
    static let productSearch = "/products/search"
    static func product(_ id: String) -> String { "/products/\(id)" }

    // Influencers
    static let influencers = "/influencers"
    static func influencer(_ id: String) -> String { "/influencers/\(id)" }

    // Combos
    static func influencerCombos(_ id: String) -> String { "/combos/influencer/\(id)" }
    static func combo(_ id: String) -> String { "/combos/\(id)" }

    // Analysis
    static let analysis = "/analysis"
    static let analysisMe = "/analysis/me"
    static let analysisFull = "/analysis/me/full"

    // Subscriptions
    static let subscriptionVerify = "/subscriptions/verify"
    static let subscriptionStatus = "/subscriptions/status"
}
