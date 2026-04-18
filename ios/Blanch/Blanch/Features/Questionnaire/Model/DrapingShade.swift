import Foundation
import SwiftUI

// MARK: - Draping Shade Catalog
//
// Eight curated lipstick shades chosen to span the undertone × depth grid.
// Each shade carries:
//   • hex — the lab color we composite onto the user's lips
//   • likelihood — multiplicative weights the scorer applies if this shade "wins"
//     an A/B pair (i.e., user says the OTHER one makes them look tired)
//
// Hardcoded for Stage 2 MVP to keep this decoupled from the backend product
// catalog. Phase 2.6 will pull from `/api/v1/products?category=lipstick`.

struct DrapingShade: Sendable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let hex: String
    // What saying "this shade flatters me" implies about my season.
    let likelihood: AnswerLikelihood

    var color: Color { Color(hex: hex) }
}

enum DrapingShadeCatalog {
    static let all: [DrapingShade] = [
        // Cool–pink family
        DrapingShade(
            id: "cool_berry",
            displayName: "Cool Berry",
            hex: "#A83E6B",
            likelihood: AnswerLikelihood(
                undertoneWarm: 0.55, undertoneCool: 1.8,
                depthLight: 0.8, depthDeep: 1.2
            )
        ),
        DrapingShade(
            id: "pink_rose",
            displayName: "Dusty Rose",
            hex: "#C97A8E",
            likelihood: AnswerLikelihood(
                undertoneWarm: 0.65, undertoneCool: 1.6,
                depthLight: 1.2, depthDeep: 0.85
            )
        ),
        DrapingShade(
            id: "blue_red",
            displayName: "Blue-Red",
            hex: "#B6213B",
            likelihood: AnswerLikelihood(
                undertoneWarm: 0.5, undertoneCool: 1.9,
                depthLight: 0.9, depthDeep: 1.1
            )
        ),
        DrapingShade(
            id: "cool_mauve",
            displayName: "Soft Mauve",
            hex: "#B88296",
            likelihood: AnswerLikelihood(
                undertoneWarm: 0.7, undertoneCool: 1.5,
                depthLight: 1.15, depthDeep: 0.9
            )
        ),

        // Warm–peach family
        DrapingShade(
            id: "warm_coral",
            displayName: "Warm Coral",
            hex: "#E07856",
            likelihood: AnswerLikelihood(
                undertoneWarm: 1.8, undertoneCool: 0.55,
                depthLight: 1.2, depthDeep: 0.85
            )
        ),
        DrapingShade(
            id: "orange_red",
            displayName: "Orange-Red",
            hex: "#C74A2B",
            likelihood: AnswerLikelihood(
                undertoneWarm: 1.9, undertoneCool: 0.5,
                depthLight: 0.85, depthDeep: 1.2
            )
        ),
        DrapingShade(
            id: "terracotta",
            displayName: "Terracotta",
            hex: "#A65640",
            likelihood: AnswerLikelihood(
                undertoneWarm: 1.7, undertoneCool: 0.6,
                depthLight: 0.8, depthDeep: 1.25
            )
        ),
        DrapingShade(
            id: "peach_nude",
            displayName: "Peach Nude",
            hex: "#D89878",
            likelihood: AnswerLikelihood(
                undertoneWarm: 1.55, undertoneCool: 0.7,
                depthLight: 1.3, depthDeep: 0.8
            )
        )
    ]
}

// MARK: - Color Hex Helper (mirrors the extension already in ProductListView)
// ProductListView.swift defines Color(hex:) at the bottom — this file can
// use it directly since Swift's module scope puts both in the same target.
