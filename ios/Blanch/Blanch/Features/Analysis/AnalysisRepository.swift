import Foundation

// MARK: - Analysis Repository
// OOP Pattern: Repository
//
// Submits an analysis outcome to the backend. The skin classifier works on
// season NAMES (bundled locally), but the backend's /analysis endpoint expects
// season UUIDs from its database. This repository fetches /seasons once to
// resolve names → ids, then POSTs the result.

protocol AnalysisRepositoryProtocol: AnyObject, Sendable {
    func submit(outcome: AnalysisOutcome) async throws -> AnalysisResultOut
    func submitQuizResult(
        primarySeasonName: String,
        rawScoresByName: [String: Double],
        source: String
    ) async throws -> AnalysisResultOut
    func getMyAnalysis() async throws -> AnalysisFreeResult
}

struct AnalysisSubmitIn: Encodable {
    let seasonId: String
    let rawScores: [String: Double]
    let selfieMetadata: [String: String]?
}

struct AnalysisResultOut: Decodable {
    let id: String
    let season: SeasonDTO
    let rawScores: [String: Double]
    let completedAt: String
}

struct AnalysisFreeResult: Decodable {
    let season: SeasonDTO
}

enum AnalysisRepositoryError: Error, LocalizedError {
    case seasonNotFound(name: String)

    var errorDescription: String? {
        switch self {
        case .seasonNotFound(let name):
            return "Backend has no season named '\(name)'. Reseed the database."
        }
    }
}

// Serializes access to the name → season_id cache so the repository itself
// can stay a simple Sendable class without manual locking in async code.
private actor SeasonIdCache {
    private var map: [String: String] = [:]

    func get() -> [String: String] { map }
    func set(_ newMap: [String: String]) { map = newMap }
}

final class AnalysisRepository: AnalysisRepositoryProtocol, Sendable {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let authManager: AuthManager
    private let cache = SeasonIdCache()

    init(networkClient: NetworkClientProtocol, baseURL: String, authManager: AuthManager) {
        self.networkClient = networkClient
        self.baseURL = baseURL
        self.authManager = authManager
    }

    func submit(outcome: AnalysisOutcome) async throws -> AnalysisResultOut {
        let idsByName = try await loadSeasonIdMap()

        guard let primaryId = idsByName[outcome.classification.primarySeasonName] else {
            throw AnalysisRepositoryError.seasonNotFound(name: outcome.classification.primarySeasonName)
        }

        var rawScoresById: [String: Double] = [:]
        for (name, score) in outcome.classification.scoresByName {
            if let id = idsByName[name] {
                rawScoresById[id] = score
            }
        }

        let body = AnalysisSubmitIn(
            seasonId: primaryId,
            rawScores: rawScoresById,
            selfieMetadata: [
                "source": "photo_picker",
                "pipeline_version": "1",
            ]
        )

        let token = await authManager.accessToken
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.analysis)
            .setMethod("POST")
            .setAuth(token)
            .setBody(body)
            .build()

        return try await networkClient.request(request)
    }

    // Quiz-based submission — no skin sample required. Same backend endpoint
    // as the CV pipeline submit; the selfieMetadata.source field distinguishes
    // them server-side for analytics.
    func submitQuizResult(
        primarySeasonName: String,
        rawScoresByName: [String: Double],
        source: String
    ) async throws -> AnalysisResultOut {
        let idsByName = try await loadSeasonIdMap()

        guard let primaryId = idsByName[primarySeasonName] else {
            throw AnalysisRepositoryError.seasonNotFound(name: primarySeasonName)
        }

        var rawScoresById: [String: Double] = [:]
        for (name, score) in rawScoresByName {
            if let id = idsByName[name] {
                rawScoresById[id] = score
            }
        }

        let body = AnalysisSubmitIn(
            seasonId: primaryId,
            rawScores: rawScoresById,
            selfieMetadata: [
                "source": source,
                "pipeline_version": "quiz_v1",
            ]
        )

        let token = await authManager.accessToken
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.analysis)
            .setMethod("POST")
            .setAuth(token)
            .setBody(body)
            .build()

        return try await networkClient.request(request)
    }

    func getMyAnalysis() async throws -> AnalysisFreeResult {
        let token = await authManager.accessToken
        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.analysisMe)
            .setAuth(token)
            .build()
        return try await networkClient.request(request)
    }

    // MARK: - Season ID lookup

    private func loadSeasonIdMap() async throws -> [String: String] {
        let cached = await cache.get()
        if !cached.isEmpty { return cached }

        let request = try RequestBuilder(baseURL: baseURL)
            .setPath(Endpoints.seasons)
            .build()
        let response: SeasonListResponse = try await networkClient.request(request)

        var map: [String: String] = [:]
        for season in response.seasons {
            map[season.name] = season.id
        }

        await cache.set(map)
        return map
    }
}
