import Foundation

// MARK: - Draping Pair Selector
//
// Given the Stage 1 posterior over 12 seasons and a catalog of shades,
// pick N pairs that maximally discriminate between the top candidates.
//
// Strategy: rank pairs by "separation score" — how differently the two
// shades would shift the posterior under opposite winners. A pair where
// shade A screams "warm" and shade B screams "cool" is maximally
// informative if the user is ambiguous warm-vs-cool.

struct DrapingPair: Sendable, Identifiable, Hashable {
    let id: String
    let shadeA: DrapingShade
    let shadeB: DrapingShade

    // Prompt is intentionally negative-framed to exploit the psychological
    // gap between "pick what's good" (hard) and "pick what's wrong" (easy).
    // Rotated across pairs so the quiz doesn't feel repetitive.
    let prompt: String
}

protocol DrapingPairSelecting: Sendable {
    func selectPairs(
        from catalog: [DrapingShade],
        posterior: [String: Double],
        palettes: [SeasonPalette],
        count: Int
    ) -> [DrapingPair]
}

struct InformationGainPairSelector: DrapingPairSelecting {
    // Negative-framed prompts. We rotate through these so consecutive
    // pairs don't feel identical; the framing stays constant (negative)
    // but the specific phrasing varies.
    private let prompts = [
        "Which one makes you look tired?",
        "Which one washes you out?",
        "Which one pulls the color out of your face?",
        "Which one makes your skin look dull?",
        "Which one clashes more with your skin?",
        "Which one ages you?"
    ]

    func selectPairs(
        from catalog: [DrapingShade],
        posterior: [String: Double],
        palettes: [SeasonPalette],
        count: Int
    ) -> [DrapingPair] {
        guard catalog.count >= 2 else { return [] }

        // Score every unordered pair by how much information it would add
        // given the current posterior. Score = KL-ish divergence between
        // the two posteriors that would result from each shade "winning".
        var scored: [(pair: (DrapingShade, DrapingShade), score: Double)] = []
        for i in 0..<catalog.count {
            for j in (i + 1)..<catalog.count {
                let a = catalog[i]
                let b = catalog[j]
                let score = informationGain(
                    a: a, b: b,
                    posterior: posterior,
                    palettes: palettes
                )
                scored.append(((a, b), score))
            }
        }

        let sorted = scored.sorted { $0.score > $1.score }

        // Greedy selection: pick top-scoring pairs but avoid reusing the
        // same shade back-to-back so the UI feels varied.
        var chosen: [DrapingPair] = []
        var lastUsed: Set<String> = []
        var promptIndex = 0

        for entry in sorted {
            if chosen.count >= count { break }
            let (a, b) = entry.pair
            if chosen.count > 0 && (lastUsed.contains(a.id) || lastUsed.contains(b.id)) {
                continue
            }
            chosen.append(DrapingPair(
                id: "\(a.id)_vs_\(b.id)",
                shadeA: a,
                shadeB: b,
                prompt: prompts[promptIndex % prompts.count]
            ))
            promptIndex += 1
            lastUsed = [a.id, b.id]
        }

        // If the anti-repeat rule left us short, top up with next-best
        // pairs regardless of repeats.
        if chosen.count < count {
            for entry in sorted {
                if chosen.count >= count { break }
                let (a, b) = entry.pair
                let id = "\(a.id)_vs_\(b.id)"
                if chosen.contains(where: { $0.id == id }) { continue }
                chosen.append(DrapingPair(
                    id: id,
                    shadeA: a,
                    shadeB: b,
                    prompt: prompts[promptIndex % prompts.count]
                ))
                promptIndex += 1
            }
        }

        return chosen
    }

    // Simulate: what would the posterior look like if shade A "won"? And B?
    // Information gain = L1 distance between the two resulting distributions.
    // Weighted by current posterior mass on the affected seasons so pairs
    // that shift the dominant candidates count more.
    private func informationGain(
        a: DrapingShade, b: DrapingShade,
        posterior: [String: Double],
        palettes: [SeasonPalette]
    ) -> Double {
        let scorer = BayesianSeasonScorer()
        let posteriorIfA = scorer.update(
            posterior: posterior, with: a.likelihood, palettes: palettes
        )
        let posteriorIfB = scorer.update(
            posterior: posterior, with: b.likelihood, palettes: palettes
        )

        var total = 0.0
        for palette in palettes {
            let pa = posteriorIfA[palette.name] ?? 0
            let pb = posteriorIfB[palette.name] ?? 0
            total += abs(pa - pb)
        }
        return total
    }
}
