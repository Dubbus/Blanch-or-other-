import Foundation

// MARK: - Season Classification Strategy
// OOP Pattern: Strategy
//
// Defines the contract for "given a sampled skin LAB, produce scores for the
// 12 color seasons." The default implementation is SkinToneAxisStrategy, which
// scores based on undertone (warm/cool), value (light/medium/deep), and chroma
// (bright/muted). Future strategies (e.g., Core ML classifier, spreadsheet rules,
// remote API) can drop in without touching the pipeline.

protocol SeasonClassificationStrategy: Sendable {
    func classify(skin: LAB, palettes: [SeasonPalette]) -> SeasonClassification
}

struct SeasonClassification: Sendable {
    // Raw scores keyed by season NAME (not backend UUID — the repository
    // resolves name → id at submission time).
    let scoresByName: [String: Double]
    let primarySeasonName: String

    var ranked: [(name: String, score: Double)] {
        scoresByName.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
}

// MARK: - Skin Tone Axis Strategy (default)
//
// Scores each of the 12 seasons by how well the skin's LAB axes align with
// that season's (undertone, category, brightness) properties. Higher score = better match.
//
// The three axes:
//   • Undertone — skin b* (CIE LAB yellow-blue axis). Positive = warm/yellow,
//     negative = cool/blue. Compared to each season's "warm" or "cool" label.
//   • Value     — skin L* (CIE LAB lightness, 0–100). Mapped to light / medium / deep
//     and compared against each season's category bucket.
//   • Chroma    — sqrt(a² + b²). Compared against the season's clarity bias
//     (bright / true / soft / light / deep).
//
// This is a v1 heuristic. It is intentionally simple so the full pipeline
// (photo → face → sample → score → submit) can be exercised end-to-end.
// The Strategy protocol lets us replace it without touching any callers.

struct SkinToneAxisStrategy: SeasonClassificationStrategy {
    func classify(skin: LAB, palettes: [SeasonPalette]) -> SeasonClassification {
        var scores: [String: Double] = [:]

        for palette in palettes {
            scores[palette.name] = score(skin: skin, palette: palette)
        }

        let top = scores.max(by: { $0.value < $1.value })?.key ?? palettes.first?.name ?? ""
        return SeasonClassification(scoresByName: scores, primarySeasonName: top)
    }

    private func score(skin: LAB, palette: SeasonPalette) -> Double {
        let undertoneScore = undertoneAlignment(skinB: skin.b, undertone: palette.undertone)
        let valueScore = valueAlignment(skinL: skin.l, category: palette.category)
        let chromaScore = chromaAlignment(skinChroma: skin.chroma, name: palette.name)

        // Weighted sum: undertone and value are equally important — otherwise
        // fair warm-toned subjects get pulled toward Deep/True variants when
        // they should land on Light. Chroma is the tiebreaker.
        return (undertoneScore * 0.40) + (valueScore * 0.40) + (chromaScore * 0.20)
    }

    // Returns 0...1. Skin b* > 0 is warm (yellow), < 0 is cool (blue).
    // For typical skin, b* is almost always positive (~10–25). We use a
    // soft threshold around b* = 14 as the neutral midpoint.
    private func undertoneAlignment(skinB: Double, undertone: String) -> Double {
        let neutral = 14.0
        let spread = 8.0
        let warmness = max(0.0, min(1.0, (skinB - (neutral - spread)) / (2 * spread)))
        return undertone == "warm" ? warmness : (1.0 - warmness)
    }

    // Skin L* → light/medium/deep buckets. Spring/Summer lean lighter,
    // Autumn/Winter lean deeper on average.
    private func valueAlignment(skinL: Double, category: String) -> Double {
        let lightness = max(0.0, min(1.0, (skinL - 35.0) / 40.0))  // 35→0, 75→1
        switch category {
        case "spring": return lightness                      // prefers lighter
        case "summer": return 1.0 - abs(lightness - 0.6)     // prefers medium-light
        case "autumn": return 1.0 - abs(lightness - 0.45)    // prefers medium
        case "winter": return 1.0 - lightness                // prefers deeper
        default: return 0.5
        }
    }

    // Chroma bias baked into the season name prefix.
    private func chromaAlignment(skinChroma: Double, name: String) -> Double {
        let normalized = max(0.0, min(1.0, (skinChroma - 8.0) / 24.0))  // 8→0, 32→1
        if name.hasPrefix("Bright") { return normalized }
        if name.hasPrefix("Soft")   { return 1.0 - normalized }
        if name.hasPrefix("Light")  { return 1.0 - abs(normalized - 0.35) }
        if name.hasPrefix("Deep")   { return 1.0 - abs(normalized - 0.6) }
        return 1.0 - abs(normalized - 0.5)  // "True" seasons = mid chroma
    }
}
