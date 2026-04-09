import Foundation

struct ComboItemDTO: Codable, Identifiable {
    let product: ProductDTO
    let role: String
    let sortOrder: Int

    var id: String { "\(product.id)-\(role)" }
}

struct LipComboDTO: Codable, Identifiable {
    let id: String
    let influencerId: String
    let name: String?
    let items: [ComboItemDTO]
}

struct LipComboListResponse: Codable {
    let total: Int
    let combos: [LipComboDTO]
}
