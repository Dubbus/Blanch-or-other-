import Foundation
import UIKit

// MARK: - Draping ViewModel
// OOP Patterns: Inheritance (BaseViewModel) + Composition + Strategy
//
// Owns the Stage 2 flow:
//   idle → processing selfie → pairs → finished
//
// Takes a SHARED posterior (reference type) from Stage 1 so the A/B answers
// compound on top of the factual-question prior. Updates the same posterior,
// so the final result view reads the combined Stage 1 + Stage 2 distribution.

@MainActor
final class DrapingViewModel: BaseViewModel {
    // Phase drives the view state machine.
    enum Phase: Sendable, Equatable {
        case idle               // waiting for user to pick selfie
        case processing         // lip detection + rendering all shades
        case pairing(index: Int) // presenting A/B pair N
        case finished           // all pairs answered or confidence hit
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var selfie: UIImage?
    @Published private(set) var pairs: [DrapingPair] = []
    @Published private(set) var renderedImages: [String: UIImage] = [:] // keyed by shade.id
    @Published private(set) var usedHeuristicLipRegion: Bool = false
    @Published private(set) var pickedShadeIds: [String] = [] // in order
    @Published private(set) var isSubmitting: Bool = false
    @Published private(set) var submitError: String?
    @Published private(set) var isSubmitted: Bool = false

    let posterior: SharedPosterior
    private let lipDetector: LipRegionDetecting
    private let renderer: LipRendering
    private let pairSelector: DrapingPairSelecting
    private let scorer: QuestionnaireScoring
    private let repository: AnalysisRepositoryProtocol?
    private let session: UserSession?

    // Target number of A/B pairs to present. 4 is the sweet spot between
    // information gain and user fatigue — each pair carries ~1.8/0.55 weights,
    // so 4 pairs can push top-season confidence from ~25% (end of Stage 1)
    // into the 70%+ range.
    private let targetPairCount = 4

    // Stop early once the leading season dominates clearly.
    private let earlyStopThreshold: Double = 0.70

    init(
        posterior: SharedPosterior,
        repository: AnalysisRepositoryProtocol? = nil,
        session: UserSession? = nil,
        lipDetector: LipRegionDetecting = LipRegionDetector(),
        renderer: LipRendering = LipRenderer(),
        pairSelector: DrapingPairSelecting = InformationGainPairSelector(),
        scorer: QuestionnaireScoring = BayesianSeasonScorer()
    ) {
        self.posterior = posterior
        self.repository = repository
        self.session = session
        self.lipDetector = lipDetector
        self.renderer = renderer
        self.pairSelector = pairSelector
        self.scorer = scorer
    }

    // MARK: - Entry

    func startDraping(with image: UIImage) async {
        selfie = image
        phase = .processing
        errorMessage = nil
        isLoading = true
        renderedImages = [:]
        pickedShadeIds = []

        do {
            try await prepareShades(image: image)
            let selected = pairSelector.selectPairs(
                from: DrapingShadeCatalog.all,
                posterior: posterior.value,
                palettes: posterior.palettes,
                count: targetPairCount
            )
            pairs = selected
            if pairs.isEmpty {
                phase = .finished
            } else {
                phase = .pairing(index: 0)
            }
        } catch let error as LipRegionError {
            errorMessage = error.errorDescription
            phase = .idle
        } catch let error as LipRendererError {
            errorMessage = error.errorDescription
            phase = .idle
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
        isLoading = false
    }

    // Detect lips once, then render every catalog shade up-front so the
    // A/B transitions are instant (no render latency per pair).
    //
    // CRITICAL: normalize orientation first. iPhone photos typically carry
    // EXIF orientation metadata (e.g. .right for portrait camera shots).
    // Vision with `orientation: .up` interprets the raw pixel data — if we
    // hand it un-normalized, it detects a sideways face and the bbox is in
    // the sideways frame, so the rendered "lipstick" lands on the forehead
    // when the UIImage's orientation metadata rotates the output back.
    // AnalysisPipeline does the same thing (see AnalysisPipeline.swift:69).
    private func prepareShades(image: UIImage) async throws {
        guard let normalized = image.normalizedToUp(),
              let cgImage = normalized.cgImage else {
            throw LipRendererError.invalidImage
        }
        let size = CGSize(width: cgImage.width, height: cgImage.height)

        let region = try await lipDetector.detectLipRegion(in: cgImage, pixelSize: size)
        usedHeuristicLipRegion = !region.isPrecise

        // Render against the NORMALIZED image so the mask coordinates line
        // up with the pixel grid Vision saw. The result UIImage then has
        // .up orientation too, so SwiftUI displays it without rotation.
        var rendered: [String: UIImage] = [:]
        for shade in DrapingShadeCatalog.all {
            let image = try await renderer.render(
                image: normalized,
                lipPolygon: region.polygon,
                hex: shade.hex
            )
            rendered[shade.id] = image
        }
        renderedImages = rendered
    }

    // MARK: - Answering

    func pick(shade: DrapingShade, rejected: DrapingShade) {
        // Negative-framed prompt: user tapped the REJECTED shade (the one
        // they said "makes you look tired"). The winner is the other shade,
        // so we apply the WINNER's likelihood to the posterior.
        _ = rejected
        pickedShadeIds.append(shade.id)
        posterior.value = scorer.update(
            posterior: posterior.value,
            with: shade.likelihood,
            palettes: posterior.palettes
        )
        advance()
    }

    private func advance() {
        guard case .pairing(let index) = phase else { return }
        let next = index + 1
        if next >= pairs.count || topConfidence >= earlyStopThreshold {
            phase = .finished
        } else {
            phase = .pairing(index: next)
        }
    }

    // MARK: - Derived

    var currentPair: DrapingPair? {
        guard case .pairing(let index) = phase, pairs.indices.contains(index) else { return nil }
        return pairs[index]
    }

    var currentIndex: Int {
        if case .pairing(let index) = phase { return index }
        return pairs.count
    }

    var topConfidence: Double {
        posterior.value.rankedSeasons.first?.probability ?? 0
    }

    // MARK: - Submit

    // POSTs the combined posterior to the backend and writes the resulting
    // season into UserSession so other tabs (Discover) can personalize.
    // If no repository/session was injected (e.g. offline preview), the
    // submit no-ops but writes to session locally so the UI still updates.
    func submit() async {
        guard !isSubmitted, !isSubmitting else { return }
        guard let name = posterior.topSeasonName else { return }

        isSubmitting = true
        submitError = nil

        do {
            if let repository {
                let result = try await repository.submitQuizResult(
                    primarySeasonName: name,
                    rawScoresByName: posterior.value,
                    source: "quiz_stage2"
                )
                session?.setSeason(
                    id: result.season.id,
                    name: result.season.name,
                    confidence: posterior.topConfidence
                )
            } else {
                // Offline / preview path — no backend, no persisted id.
                session?.setSeason(
                    id: "",
                    name: name,
                    confidence: posterior.topConfidence
                )
            }
            isSubmitted = true
        } catch let error as NetworkError {
            submitError = error.errorDescription
        } catch let error as AnalysisRepositoryError {
            submitError = error.errorDescription
        } catch {
            submitError = error.localizedDescription
        }

        isSubmitting = false
    }

    func restart() {
        phase = .idle
        selfie = nil
        pairs = []
        renderedImages = [:]
        pickedShadeIds = []
        errorMessage = nil
        submitError = nil
        isSubmitted = false
    }
}

// MARK: - UIImage orientation helper
// Same pattern AnalysisPipeline uses — bake EXIF rotation into pixel data
// so Vision and CoreImage both see an upright image.

private extension UIImage {
    func normalizedToUp() -> UIImage? {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
