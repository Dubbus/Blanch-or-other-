import Foundation

// MARK: - Questionnaire Scorer
// OOP Pattern: Strategy
//
// Separate from SeasonClassificationStrategy (which takes LAB from CV)
// because this takes a stream of AnswerLikelihoods from user taps.
// Different input, same output shape: a distribution over 12 seasons.
//
// Phase 3.6 adds updateFamilyPhase (chroma-blind, all 12 seasons) and the
// standard update is used for variant-phase answers (chroma-aware, but only
// the 3 collapsed seasons are in the posterior, so signal-to-noise triples).

protocol QuestionnaireScoring: Sendable {
    func initialPosterior(palettes: [SeasonPalette]) -> [String: Double]

    // Standard update — applies all axes including chroma.
    // Used for Stage 2 draping and variant-phase quiz answers.
    func update(
        posterior: [String: Double],
        with likelihood: AnswerLikelihood,
        palettes: [SeasonPalette]
    ) -> [String: Double]

    // Family-phase update — strips chroma signals to avoid leaking
    // within-family chroma bias into cross-family undertone/depth questions.
    func updateFamilyPhase(
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
            guard prior > 0 else { continue }
            let weight = likelihoodWeight(for: palette, likelihood: likelihood)
            updated[palette.name] = prior * weight
        }
        // Also carry through any season entries not in palettes
        // (occurs in variant phase when posterior is collapsed to 3 seasons
        //  and palettes still contains all 12).
        for (name, value) in posterior where updated[name] == nil {
            // If no palette found for this season, keep its value unchanged
            // so it participates in normalisation.
            if !palettes.contains(where: { $0.name == name }) {
                updated[name] = value
            }
        }
        return normalized(updated)
    }

    func updateFamilyPhase(
        posterior: [String: Double],
        with likelihood: AnswerLikelihood,
        palettes: [SeasonPalette]
    ) -> [String: Double] {
        // Strip chroma before applying — chroma is a within-family discriminator
        // and must not contaminate cross-family undertone/depth questions.
        let chromaBlind = AnswerLikelihood(
            undertoneWarm: likelihood.undertoneWarm,
            undertoneCool: likelihood.undertoneCool,
            depthLight: likelihood.depthLight,
            depthDeep: likelihood.depthDeep,
            chromaVivid: 1.0,
            chromaMuted: 1.0
        )
        return update(posterior: posterior, with: chromaBlind, palettes: palettes)
    }

    // MARK: - Weight calculation

    private func likelihoodWeight(for palette: SeasonPalette, likelihood: AnswerLikelihood) -> Double {
        let undertone = palette.undertone == "warm" ? likelihood.undertoneWarm : likelihood.undertoneCool
        let depth = depthWeight(category: palette.category, likelihood: likelihood)
        let chroma = chromaWeight(name: palette.name, likelihood: likelihood)
        return undertone * depth * chroma
    }

    private func depthWeight(category: String, likelihood: AnswerLikelihood) -> Double {
        switch category {
        case "spring": return likelihood.depthLight
        case "winter": return likelihood.depthDeep
        case "summer": return (likelihood.depthLight * 0.5 + 1.0 * 0.5)
        case "autumn": return (likelihood.depthDeep * 0.5 + 1.0 * 0.5)
        default: return 1.0
        }
    }

    // Chroma/clarity axis weights per season variant.
    // v = chromaVivid deviation from 1.0; m = chromaMuted deviation from 1.0.
    //
    // Phase 3.6 calibration:
    //   Light Spring   — bumped muted signal (0.15→0.55) to separate from True Spring
    //   Light Summer   — adjusted to be slightly more vivid-tolerant than True/Soft Summer
    //   Dark Autumn    — slightly more vivid than Soft Autumn (deep jewel tones)
    private func chromaWeight(name: String, likelihood: AnswerLikelihood) -> Double {
        let v = likelihood.chromaVivid - 1.0
        let m = likelihood.chromaMuted - 1.0
        switch name {
        // Fully vivid: best in maximum saturation
        case "Bright Winter", "Bright Spring":
            return 1.0 + v * 1.0
        // Moderately vivid: clear but not neon
        case "True Winter", "True Spring":
            return 1.0 + v * 0.75
        // Deep Winter: depth-driven; mild chroma signal
        case "Deep Winter":
            return 1.0 + v * 0.15 + m * 0.1
        // Light Spring: soft, powdery warm pastels — penalised by vivid, boosted by muted
        case "Light Spring":
            return 1.0 + v * 0.12 + m * 0.55
        // Light Summer: airy cool — slightly more vivid-tolerant than True/Soft Summer
        case "Light Summer":
            return 1.0 + m * 0.4 + v * 0.22
        // True Summer: clearly muted, grayed palette
        case "True Summer":
            return 1.0 + m * 0.6
        // True Autumn: medium saturation earthy — neither fully muted nor vivid
        case "True Autumn":
            return 1.0 + m * 0.3 + v * 0.2
        // Dark Autumn: deep and somewhat vivid — jewel-toned earthy; more vivid than Soft
        case "Dark Autumn":
            return 1.0 + m * 0.2 + v * 0.28
        // Fully muted: best in grayed, toned-down colors
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
