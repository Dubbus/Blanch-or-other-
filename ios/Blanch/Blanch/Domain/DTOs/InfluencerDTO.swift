import Foundation

struct InfluencerDTO: Codable, Identifiable, Hashable {
    let id: String
    let handle: String
    let platform: String
    let displayName: String?
    let avatarUrl: String?
    let followerCount: Int?
    let primarySeasonId: String?
    let bio: String?
    let instagramUrl: String?
    let tiktokUrl: String?

    var formattedFollowers: String {
        guard let count = followerCount else { return "" }
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

struct InfluencerListResponse: Codable {
    let total: Int
    let influencers: [InfluencerDTO]
}
