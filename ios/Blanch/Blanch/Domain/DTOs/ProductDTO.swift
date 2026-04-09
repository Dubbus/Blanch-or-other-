import Foundation

// MARK: - Data Transfer Objects (DTOs)
// DTOs are simple Codable structs that match the API JSON exactly.
// They exist at the boundary between the network layer and the domain layer.
// Unlike rich domain models (classes with behavior), DTOs are dumb data containers.

struct ProductDTO: Codable, Identifiable, Hashable {
    let id: String
    let brand: String
    let name: String
    let category: String
    let shadeName: String?
    let hexCode: String?
    let swatchUrl: String?
    let productUrl: String?
    let affiliateUrl: String?
    let retailer: String?
    let priceCents: Int?
    let imageUrl: String?

    var formattedPrice: String? {
        guard let cents = priceCents else { return nil }
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var displayName: String {
        if let shade = shadeName {
            return "\(brand) \(name) — \(shade)"
        }
        return "\(brand) \(name)"
    }
}

struct ProductSeasonInfo: Codable {
    let seasonId: String
    let seasonName: String
    let confidence: Double
}

struct ProductWithSeasons: Codable, Identifiable {
    let id: String
    let brand: String
    let name: String
    let category: String
    let shadeName: String?
    let hexCode: String?
    let swatchUrl: String?
    let productUrl: String?
    let affiliateUrl: String?
    let retailer: String?
    let priceCents: Int?
    let imageUrl: String?
    let seasons: [ProductSeasonInfo]
}

struct ProductListResponse: Codable {
    let total: Int
    let products: [ProductDTO]
}
