import Foundation
import SwiftUI

// MARK: - Draping Shade Catalog
//
// Eight curated lipstick shades spanning the undertone × depth grid.
// Each shade carries:
//   • hex — the lab color composited onto the user's lips
//   • likelihood — multiplicative weights applied if this shade "wins" an A/B
//     (i.e., the user says the OTHER one makes them look tired)
//
// Phase 3.6: added shades(for:) which returns the 4 most discriminating shades
// for the identified season family, halving the Stage 2 space and doubling the
// information gain per pair.
//
// CALIBRATION (Phase 3.1): weights reduced to 70% of original deviation from 1.0.

struct DrapingShade: Sendable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let hex: String
    let likelihood: AnswerLikelihood

    var color: Color { Color(hex: hex) }
}

enum DrapingShadeCatalog {

    // MARK: - Full catalog (8 shades)

    static let all: [DrapingShade] = [
        // Cool–pink family
        coolBerry,
        dustyRose,
        blueRed,
        softMauve,
        // Warm–peach family
        warmCoral,
        orangeRed,
        terracotta,
        peachNude
    ]

    // MARK: - Individual shades

    // True/Deep Winter territory — saturated blue-magenta
    static let coolBerry = DrapingShade(
        id: "cool_berry",
        displayName: "Cool Berry",
        hex: "#A83E6B",
        likelihood: AnswerLikelihood(
            undertoneWarm: 0.68, undertoneCool: 1.56,
            depthLight: 0.86, depthDeep: 1.14,
            chromaVivid: 1.21, chromaMuted: 0.87
        )
    )

    // Soft/Light Summer territory — grayed, soft pink
    static let dustyRose = DrapingShade(
        id: "pink_rose",
        displayName: "Dusty Rose",
        hex: "#C97A8E",
        likelihood: AnswerLikelihood(
            undertoneWarm: 0.76, undertoneCool: 1.42,
            depthLight: 1.14, depthDeep: 0.90,
            chromaVivid: 0.85, chromaMuted: 1.32
        )
    )

    // Bright/True Winter signature — most vivid blue-red possible
    static let blueRed = DrapingShade(
        id: "blue_red",
        displayName: "Blue-Red",
        hex: "#B6213B",
        likelihood: AnswerLikelihood(
            undertoneWarm: 0.65, undertoneCool: 1.63,
            depthLight: 0.93, depthDeep: 1.07,
            chromaVivid: 1.42, chromaMuted: 0.76
        )
    )

    // Soft Summer / Soft Autumn — most muted cool shade
    static let softMauve = DrapingShade(
        id: "cool_mauve",
        displayName: "Soft Mauve",
        hex: "#B88296",
        likelihood: AnswerLikelihood(
            undertoneWarm: 0.79, undertoneCool: 1.35,
            depthLight: 1.11, depthDeep: 0.93,
            chromaVivid: 0.79, chromaMuted: 1.39
        )
    )

    // True Spring / Bright Spring — vivid clear coral
    static let warmCoral = DrapingShade(
        id: "warm_coral",
        displayName: "Warm Coral",
        hex: "#E07856",
        likelihood: AnswerLikelihood(
            undertoneWarm: 1.56, undertoneCool: 0.68,
            depthLight: 1.14, depthDeep: 0.90,
            chromaVivid: 1.32, chromaMuted: 0.85
        )
    )

    // Bright Spring / True Autumn edge — vivid warm red
    static let orangeRed = DrapingShade(
        id: "orange_red",
        displayName: "Orange-Red",
        hex: "#C74A2B",
        likelihood: AnswerLikelihood(
            undertoneWarm: 1.63, undertoneCool: 0.65,
            depthLight: 0.90, depthDeep: 1.14,
            chromaVivid: 1.18, chromaMuted: 0.90
        )
    )

    // True / Soft / Dark Autumn — muted earthy warm
    static let terracotta = DrapingShade(
        id: "terracotta",
        displayName: "Terracotta",
        hex: "#A65640",
        likelihood: AnswerLikelihood(
            undertoneWarm: 1.49, undertoneCool: 0.72,
            depthLight: 0.86, depthDeep: 1.18,
            chromaVivid: 0.80, chromaMuted: 1.35
        )
    )

    // Light Spring / Light Summer — light, soft warm
    static let peachNude = DrapingShade(
        id: "peach_nude",
        displayName: "Peach Nude",
        hex: "#D89878",
        likelihood: AnswerLikelihood(
            undertoneWarm: 1.39, undertoneCool: 0.79,
            depthLight: 1.21, depthDeep: 0.86,
            chromaVivid: 0.92, chromaMuted: 1.14
        )
    )

    // MARK: - Family-specific catalogs (Phase 3.6)
    //
    // Returns the 4 most discriminating shades for the identified family.
    // Reduces Stage 2 space from 8 → 4 shades, doubling information gain per pair.
    //
    // Winter: cool-undertone shades spanning vivid→muted and light→deep
    // Summer: cool shades spanning muted→light
    // Spring: warm shades spanning vivid→soft and light→medium
    // Autumn: warm shades spanning vivid→muted and medium→deep

    static func shades(for family: SeasonFamily) -> [DrapingShade] {
        switch family {
        case .winter:
            // blue_red → Bright Winter; cool_berry → True/Deep Winter;
            // soft_mauve → True Winter boundary; dusty_rose → Light Winter end
            return [blueRed, coolBerry, softMauve, dustyRose]
        case .summer:
            // soft_mauve → Soft Summer; dusty_rose → Light/True Summer;
            // cool_berry → True Summer (less muted); peach_nude → warm vs cool test
            return [softMauve, dustyRose, coolBerry, peachNude]
        case .spring:
            // orange_red → Bright Spring; warm_coral → True Spring;
            // peach_nude → Light Spring; dusty_rose → cool end (anti-warm test)
            return [orangeRed, warmCoral, peachNude, dustyRose]
        case .autumn:
            // terracotta → Soft/True/Dark Autumn; orange_red → vivid True/Dark Autumn;
            // peach_nude → lighter Soft Autumn end; soft_mauve → muted test
            return [terracotta, orangeRed, peachNude, softMauve]
        }
    }
}
