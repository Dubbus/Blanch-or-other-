import Foundation
import Combine

// MARK: - User Session
//
// Shared source of truth for the user's current color season.
// Distinct from AuthManager (which owns auth state) — this owns the
// LATEST quiz/analysis result so tabs other than Quiz can personalize.
//
// Persisted to UserDefaults so it survives app restarts. Any view model
// can hold a reference and observe @Published changes reactively.

@MainActor
final class UserSession: ObservableObject {
    @Published private(set) var currentSeasonId: String?
    @Published private(set) var currentSeasonName: String?
    @Published private(set) var currentConfidence: Double?

    private let defaults: UserDefaults
    private enum Keys {
        static let id = "user_season_id"
        static let name = "user_season_name"
        static let confidence = "user_season_confidence"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentSeasonId = defaults.string(forKey: Keys.id)
        self.currentSeasonName = defaults.string(forKey: Keys.name)
        let stored = defaults.double(forKey: Keys.confidence)
        self.currentConfidence = stored > 0 ? stored : nil
    }

    func setSeason(id: String, name: String, confidence: Double) {
        currentSeasonId = id
        currentSeasonName = name
        currentConfidence = confidence
        defaults.set(id, forKey: Keys.id)
        defaults.set(name, forKey: Keys.name)
        defaults.set(confidence, forKey: Keys.confidence)
    }

    func clear() {
        currentSeasonId = nil
        currentSeasonName = nil
        currentConfidence = nil
        defaults.removeObject(forKey: Keys.id)
        defaults.removeObject(forKey: Keys.name)
        defaults.removeObject(forKey: Keys.confidence)
    }
}
