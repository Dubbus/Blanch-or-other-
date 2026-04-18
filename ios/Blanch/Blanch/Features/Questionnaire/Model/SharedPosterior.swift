import Foundation
import Combine

// MARK: - Shared Posterior
//
// A tiny reference type that holds the running posterior over seasons
// so Stage 1 and Stage 2 can mutate the same distribution. Without this,
// we'd be threading a `@Binding` through view-model boundaries, which
// SwiftUI supports poorly for compound mutations.
//
// Also stores the loaded palettes — both stages need them.

@MainActor
final class SharedPosterior: ObservableObject {
    @Published var value: [String: Double] = [:]
    @Published var palettes: [SeasonPalette] = []

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
