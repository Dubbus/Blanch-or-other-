import Foundation

// MARK: - Questionnaire Scorer
// OOP Pattern: Strategy
//
// Separate from SeasonClassificationStrategy (which takes LAB from CV)
// because this takes a stream of AnswerLikelihoods from user taps.
// Different input, same output shape: a distribution over 12 seasons.
// A later hybrid strategy can multiply the two posteriors together.

protocol QuestionnaireScoring: Sendable {
    func initialPosterior(palettes: [SeasonPalette]) -> [String: Double]
    func update(
        posterior: [String: Double],
        with likelihood: AnswerLikelihood,
        palettes: [SeasonPalette]
    ) -> [String: Double]
}

struct BayesianSeasonScorer: QuestionnaireScoring {
    func initialPosterior(palettes: [SeasonPalette]) -> [String: Double] {
        let uniform = 1.0 / Double(max(palettes.count, 1))
        var out: [String: Double] = [:]
        for p in palettes { out[p.name] = uniform }
        return out
    }

    func update(
        posterior: [String: Double],
        with likelihood: AnswerLikelihood,
        palettes: [SeasonPalette]
    ) -> [String: Double] {
        var updated: [String: Double] = [:]
        for palette in palettes {
            let prior = posterior[palette.name] ?? 0
            let weight = likelihoodWeight(for: palette, likelihood: likelihood)
            updated[palette.name] = prior * weight
        }
        return normalized(updated)
    }

    // Maps per-answer axis likelihoods onto a specific season's (undertone, category).
    private func likelihoodWeight(for palette: SeasonPalette, likelihood: AnswerLikelihood) -> Double {
        let undertone = palette.undertone == "warm" ? likelihood.undertoneWarm : likelihood.undertoneCool
        let depth = depthWeight(category: palette.category, likelihood: likelihood)
        return undertone * depth
    }

    // Category → light/deep axis. Neutral for summer/autumn (middle buckets).
    private func depthWeight(category: String, likelihood: AnswerLikelihood) -> Double {
        switch category {
        case "spring": return likelihood.depthLight
        case "winter": return likelihood.depthDeep
        case "summer": return (likelihood.depthLight * 0.5 + 1.0 * 0.5)
        case "autumn": return (likelihood.depthDeep * 0.5 + 1.0 * 0.5)
        default: return 1.0
        }
    }

    private func normalized(_ scores: [String: Double]) -> [String: Double] {
        let total = scores.values.reduce(0, +)
        guard total > 0 else { return scores }
        var out: [String: Double] = [:]
        for (k, v) in scores { out[k] = v / total }
        return out
    }
}

// MARK: - Result Helpers

extension Dictionary where Key == String, Value == Double {
    var rankedSeasons: [(name: String, probability: Double)] {
        sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
}
