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

    // Maps per-answer axis likelihoods onto a specific season's (undertone, category, chroma).
    private func likelihoodWeight(for palette: SeasonPalette, likelihood: AnswerLikelihood) -> Double {
        let undertone = palette.undertone == "warm" ? likelihood.undertoneWarm : likelihood.undertoneCool
        let depth = depthWeight(category: palette.category, likelihood: likelihood)
        let chroma = chromaWeight(name: palette.name, likelihood: likelihood)
        return undertone * depth * chroma
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

    // Season-name → chroma/clarity axis. Bright/True seasons favor vivid;
    // Soft/Light seasons favor muted. Fractions below are the signal strength
    // each variant carries on the chroma axis — Bright carries the full signal,
    // True carries 60%, Light/Soft carry mixed or full muted signal, etc.
    // v = chromaVivid deviation from 1.0; m = chromaMuted deviation from 1.0.
    private func chromaWeight(name: String, likelihood: AnswerLikelihood) -> Double {
        let v = likelihood.chromaVivid - 1.0
        let m = likelihood.chromaMuted - 1.0
        switch name {
        // Fully vivid: Bright seasons look best in the clearest, most saturated colors.
        case "Bright Winter", "Bright Spring":
            return 1.0 + v * 1.0
        // Moderately vivid: True seasons prefer clear colors but not extreme saturation.
        case "True Winter", "True Spring":
            return 1.0 + v * 0.6
        // Deep Winter: vivid but primarily driven by depth; mild chroma signal.
        case "Deep Winter":
            return 1.0 + v * 0.15 + m * 0.1
        // Light Spring: light and clear, but not as vivid as True/Bright Spring.
        case "Light Spring":
            return 1.0 + v * 0.25 + m * 0.15
        // Light Summer: cool and light; moderately muted.
        case "Light Summer":
            return 1.0 + m * 0.35 + v * 0.1
        // True Summer: clearly muted, grayed palette — stronger muted signal than Autumn.
        case "True Summer":
            return 1.0 + m * 0.6
        // True Autumn: medium saturation — can wear earthy-vivid (orange-red, burnt sienna)
        // but not as muted as Soft Autumn. Separated from True Summer intentionally.
        case "True Autumn":
            return 1.0 + m * 0.3 + v * 0.15
        // Dark Autumn: deep and muted; slight depth-muted lean over vivid.
        case "Dark Autumn":
            return 1.0 + m * 0.35 + v * 0.1
        // Fully muted: Soft seasons always look best in grayed, toned-down colors.
        case "Soft Summer", "Soft Autumn":
            return 1.0 + m * 1.0
        default:
            return 1.0
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
