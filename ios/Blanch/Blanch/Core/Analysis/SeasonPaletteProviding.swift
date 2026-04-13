import Foundation

// MARK: - Season Palette Provider
// OOP Pattern: Protocol (Interface Segregation)
//
// Abstracts WHERE the 12 season palettes come from.
// Default impl is BundledSeasonPaletteProvider which reads from a local JSON
// resource so analysis works offline. A future RemoteSeasonPaletteProvider
// can swap in without touching the classifier.

protocol SeasonPaletteProviding: Sendable {
    func loadPalettes() throws -> [SeasonPalette]
}

struct SeasonPalette: Codable, Sendable, Hashable {
    let name: String
    let category: String
    let undertone: String
    let hexPalette: [String]
}

enum SeasonPaletteError: Error, LocalizedError {
    case resourceMissing
    case decodeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .resourceMissing: return "SeasonPalettes.json is missing from the app bundle"
        case .decodeFailed(let error): return "Failed to decode SeasonPalettes.json: \(error.localizedDescription)"
        }
    }
}

// MARK: - Bundled Provider

final class BundledSeasonPaletteProvider: SeasonPaletteProviding, Sendable {
    private let resourceName: String
    private let bundle: Bundle

    init(resourceName: String = "SeasonPalettes", bundle: Bundle = .main) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    func loadPalettes() throws -> [SeasonPalette] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw SeasonPaletteError.resourceMissing
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([SeasonPalette].self, from: data)
        } catch {
            throw SeasonPaletteError.decodeFailed(error)
        }
    }
}
