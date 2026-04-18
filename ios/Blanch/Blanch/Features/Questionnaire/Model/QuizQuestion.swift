import Foundation

// MARK: - Questionnaire Model
//
// Stage 1 of the draping quiz: factual questions a makeup artist would ask
// (vein color, jewelry preference, sun behavior, flattering whites). These
// are FACTS, not aesthetic judgments — the user doesn't have to "have taste"
// to answer correctly, which is the differentiation vs. Colorwise-style
// "pick what looks good" pickers.
//
// Each answer carries multiplicative likelihoods over the 12-season axes.
// A value of 1.0 is neutral (no information). Values >1 favor, <1 penalize.
// The scorer multiplies these into a running posterior over seasons.

struct QuizQuestion: Sendable, Identifiable, Hashable {
    let id: String
    let prompt: String
    let helperText: String?
    let options: [QuizAnswer]
}

struct QuizAnswer: Sendable, Identifiable, Hashable {
    let id: String
    let label: String
    let detail: String?
    let likelihood: AnswerLikelihood
}

// Multiplicative weights applied to the posterior per axis bucket.
// 1.0 = no information on this axis; the posterior is unchanged.
struct AnswerLikelihood: Sendable, Hashable {
    var undertoneWarm: Double = 1.0
    var undertoneCool: Double = 1.0
    // Category-level depth leanings. Mapped to palette.category:
    // spring→light-leaning, summer→mid-light, autumn→mid-deep, winter→deep-leaning.
    var depthLight: Double = 1.0
    var depthDeep: Double = 1.0
}
