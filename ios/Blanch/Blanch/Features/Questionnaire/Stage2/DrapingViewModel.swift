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
        case tiebreaker         // presenting the Stage 3 final A/B
        case finished           // quiz complete
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var selfie: UIImage?
    @Published private(set) var pairs: [DrapingPair] = []
    @Published private(set) var tiebreakerPair: DrapingPair?
    @Published private(set) var renderedImages: [String: UIImage] = [:] // keyed by shade.id
    @Published private(set) var usedHeuristicLipRegion: Bool = false
    @Published private(set) var pickedShadeIds: [String] = [] // in order
    @Published private(set) var isSubmitting: Bool = false
    @Published private(set) var submitError: String?
    @Published private(set) var isSubmitted: Bool = false

    private var posteriorHistory: [[String: Double]] = []

    let posterior: SharedPosterior
    private let lipDetector: LipRegionDetecting
    private let renderer: LipRendering
    private let pairSelector: DrapingPairSelecting
    private let tiebreakerBuilder: TiebreakerBuilding
    private let scorer: QuestionnaireScoring
    private let repository: AnalysisRepositoryProtocol?
    private let session: UserSession?

    // Stage 3 tiebreaker applies a stronger likelihood weight (squared in
    // effect — calling the scorer update twice). Makes the final A/B
    // decisively break ambiguous top-2 situations.
    private let tiebreakerWeightFactor = 2

    // Target number of A/B pairs to present. Reduced from 4 → 3 for the
    // calibration pass: fewer pairs means less cumulative noise while we
    // verify the Stage 2 weights are directionally correct.
    private let targetPairCount = 3

    // Stop early once the leading season dominates clearly.
    private let earlyStopThreshold: Double = 0.70

    init(
        posterior: SharedPosterior,
        repository: AnalysisRepositoryProtocol? = nil,
        session: UserSession? = nil,
        lipDetector: LipRegionDetecting = LipRegionDetector(),
        renderer: LipRendering = LipRenderer(),
        pairSelector: DrapingPairSelecting = InformationGainPairSelector(),
        tiebreakerBuilder: TiebreakerBuilding = TopSeasonTiebreakerBuilder(),
        scorer: QuestionnaireScoring = BayesianSeasonScorer()
    ) {
        self.posterior = posterior
        self.repository = repository
        self.session = session
        self.lipDetector = lipDetector
        self.renderer = renderer
        self.pairSelector = pairSelector
        self.tiebreakerBuilder = tiebreakerBuilder
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
            let catalog = activeCatalog
            try await prepareShades(image: image, catalog: catalog)
            let selected = pairSelector.selectPairs(
                from: catalog,
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

    // The shade catalog to use for this session. Uses the 4 family-specific
    // shades when a family has been identified (Phase 3.6), otherwise all 8.
    private var activeCatalog: [DrapingShade] {
        if let family = posterior.identifiedFamily {
            return DrapingShadeCatalog.shades(for: family)
        }
        return DrapingShadeCatalog.all
    }

    // Detect lips once, then render the active catalog shades up-front so
    // A/B transitions are instant (no render latency per pair).
    //
    // CRITICAL: normalize orientation first. iPhone photos carry EXIF metadata;
    // Vision with .up orientation reads raw pixels — un-normalized = sideways face.
    private func prepareShades(image: UIImage, catalog: [DrapingShade]) async throws {
        guard let normalized = image.normalizedToUp(),
              let cgImage = normalized.cgImage else {
            throw LipRendererError.invalidImage
        }
        let size = CGSize(width: cgImage.width, height: cgImage.height)

        let region = try await lipDetector.detectLipRegion(in: cgImage, pixelSize: size)
        usedHeuristicLipRegion = !region.isPrecise

        var rendered: [String: UIImage] = [:]
        for shade in catalog {
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
        posteriorHistory.append(posterior.value)
        pickedShadeIds.append(shade.id)

        // Tiebreaker uses positive framing ("which feels more like you?"),
        // so the winner is what the user tapped. Stage 2 pairs use negative
        // framing ("which makes you look tired?") and the ViewModel already
        // receives the computed winner from the view. Either way, apply
        // the winner's likelihood to the posterior.
        let isTiebreaker = (phase == .tiebreaker)
        let repeats = isTiebreaker ? tiebreakerWeightFactor : 1
        for _ in 0..<repeats {
            posterior.value = scorer.update(
                posterior: posterior.value,
                with: shade.likelihood,
                palettes: posterior.palettes
            )
        }
        let stageLabel = isTiebreaker ? "Stage3-Tiebreaker" : "Stage2-Pair\(pickedShadeIds.count)"
        logPosterior(stage: stageLabel, winner: shade.id, loser: rejected.id)
        advance()
    }

    var canGoBack: Bool {
        switch phase {
        case .pairing(let index): return index > 0
        case .tiebreaker: return true
        default: return false
        }
    }

    func goBack() {
        guard canGoBack, !posteriorHistory.isEmpty else { return }
        posterior.value = posteriorHistory.removeLast()
        pickedShadeIds.removeLast()

        if phase == .tiebreaker {
            phase = .pairing(index: pairs.count - 1)
        } else if case .pairing(let index) = phase, index > 0 {
            phase = .pairing(index: index - 1)
        }
    }

    private func logPosterior(stage: String, winner: String, loser: String) {
#if DEBUG
        let top5 = posterior.value.rankedSeasons.prefix(5)
            .map { String(format: "%@ %.1f%%", $0.name, $0.probability * 100) }
            .joined(separator: " | ")
        print("[Blanch \(stage)] won=\(winner) lost=\(loser) → \(top5)")
#endif
    }

    private func advance() {
        if case .pairing(let index) = phase {
            let next = index + 1
            if next >= pairs.count {
                moveToTiebreakerOrFinish()
            } else {
                phase = .pairing(index: next)
            }
            return
        }
        if phase == .tiebreaker {
            phase = .finished
        }
    }

    // Between Stage 2 and Stage 3: build the final A/B from the top-2
    // seasons. If no meaningful runner-up exists (e.g. one season already
    // dominates), skip Stage 3 and go straight to finished.
    private func moveToTiebreakerOrFinish() {
        guard topConfidence < earlyStopThreshold else {
            phase = .finished
            return
        }
        if let pair = tiebreakerBuilder.buildTiebreaker(
            from: activeCatalog,
            posterior: posterior.value,
            palettes: posterior.palettes
        ) {
            tiebreakerPair = pair
            phase = .tiebreaker
        } else {
            phase = .finished
        }
    }

    // MARK: - Derived

    var currentPair: DrapingPair? {
        if case .pairing(let index) = phase, pairs.indices.contains(index) {
            return pairs[index]
        }
        if phase == .tiebreaker {
            return tiebreakerPair
        }
        return nil
    }

    var currentIndex: Int {
        if case .pairing(let index) = phase { return index }
        if phase == .tiebreaker { return pairs.count }
        return pairs.count
    }

    // Total pair count including the Stage 3 tiebreaker when it's been built.
    var totalPairCount: Int {
        pairs.count + (tiebreakerPair == nil ? 0 : 1)
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
        posteriorHistory = []
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
