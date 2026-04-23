import Foundation

// MARK: - Season Family
//
// Phase 3.6 — Two-phase quiz restructure.
//
// Organises the 12 seasons into 4 families (undertone × depth quadrants).
// The quiz first identifies the family (cross-family questions), then collapses
// the posterior to the 3 variants within that family and runs targeted
// variant-discrimination questions with stronger chroma signals.

enum SeasonFamily: String, CaseIterable, Sendable, Hashable {
    case spring, summer, autumn, winter

    var displayName: String { rawValue.capitalized }

    // The 3 variant season names within this family.
    var seasons: [String] {
        switch self {
        case .spring:  return ["Bright Spring", "True Spring", "Light Spring"]
        case .summer:  return ["Light Summer", "True Summer", "Soft Summer"]
        case .autumn:  return ["True Autumn", "Soft Autumn", "Dark Autumn"]
        case .winter:  return ["Bright Winter", "True Winter", "Deep Winter"]
        }
    }

    // One-line description shown on the family reveal card.
    var revealTagline: String {
        switch self {
        case .spring:  return "Warm, light, and clear — now let's find your exact variant."
        case .summer:  return "Cool and soft — now let's find your exact variant."
        case .autumn:  return "Warm and muted — now let's find your exact variant."
        case .winter:  return "Cool and bold — now let's find your exact variant."
        }
    }

    // Returns the dominant family if any family holds ≥ threshold combined mass.
    static func dominantFamily(
        from posterior: [String: Double],
        threshold: Double = 0.65
    ) -> SeasonFamily? {
        for family in allCases {
            let mass = family.seasons.compactMap { posterior[$0] }.reduce(0, +)
            if mass >= threshold { return family }
        }
        return nil
    }

    // Returns the family with the highest combined posterior mass (fallback
    // when no family clears the confidence threshold after all questions).
    static func topFamily(from posterior: [String: Double]) -> SeasonFamily {
        allCases.max {
            let a = $0.seasons.compactMap { posterior[$0] }.reduce(0, +)
            let b = $1.seasons.compactMap { posterior[$0] }.reduce(0, +)
            return a < b
        } ?? .winter
    }

    // Renormalize the posterior over only the 3 variants of this family.
    // Discards probability mass from the other 9 seasons.
    func collapse(posterior: [String: Double]) -> [String: Double] {
        var sub: [String: Double] = [:]
        for name in seasons { sub[name] = posterior[name] ?? 0 }
        let total = sub.values.reduce(0, +)
        guard total > 0 else {
            let uniform = 1.0 / Double(seasons.count)
            return Dictionary(uniqueKeysWithValues: seasons.map { ($0, uniform) })
        }
        return sub.mapValues { $0 / total }
    }
}
