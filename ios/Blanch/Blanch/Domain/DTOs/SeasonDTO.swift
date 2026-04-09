import Foundation

struct SeasonDTO: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let undertone: String
    let category: String
    let description: String?
    let hexPalette: [String]
}

struct SeasonListResponse: Codable {
    let seasons: [SeasonDTO]
}
