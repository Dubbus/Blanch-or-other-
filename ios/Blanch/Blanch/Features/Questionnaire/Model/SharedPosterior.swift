import Foundation
import Combine

// MARK: - Shared Posterior
//
// Reference type holding the running posterior over seasons so Stage 1 and
// Stage 2 can mutate the same distribution across view-model boundaries.
// Also stores the loaded palettes and — after Phase 3.6 — the identified
// season family so Stage 2 can restrict its shade catalog to the family.

@MainActor
final class SharedPosterior: ObservableObject {
    @Published var value: [String: Double] = [:]
    @Published var palettes: [SeasonPalette] = []

    // Set by QuestionnaireViewModel when the family phase reaches ≥ 65%
    // confidence on one family. Stage 2 reads this to pick its shade catalog.
    @Published var identifiedFamily: SeasonFamily? = nil

    init(value: [String: Double] = [:], palettes: [SeasonPalette] = []) {
        self.value = value
        self.palettes = palettes
    }

    var rankedSeasons: [(name: String, probability: Double)] {
        value.rankedSeasons
    }

    var topSeasonName: String? {
        rankedSeasons.first?.name
    }

    var topConfidence: Double {
        rankedSeasons.first?.probability ?? 0
    }
}
