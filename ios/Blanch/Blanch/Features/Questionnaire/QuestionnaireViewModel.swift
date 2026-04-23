import Foundation

// MARK: - Questionnaire ViewModel
// OOP Patterns: Inheritance (BaseViewModel) + Template Method + Strategy
//
// Phase 3.6: two-phase quiz.
//   Phase A (family): runs cross-family undertone/depth questions against all
//   12 seasons using chroma-blind scoring. Ends when one family accumulates
//   ≥ 65% posterior mass (or all 8 questions are exhausted).
//
//   Phase B (variant): collapses the posterior to 3 seasons within the
//   identified family, then runs family-specific chroma questions with the
//   full chroma-aware scorer. Signal-to-noise triples because only 3 seasons
//   compete for each update.

@MainActor
final class QuestionnaireViewModel: BaseViewModel {

    // MARK: - Quiz phase

    enum QuizPhase: Equatable {
        case family
        case variant(SeasonFamily)
    }

    // MARK: - Published state

    @Published private(set) var questions: [QuizQuestion] = Stage1Questions.familyPhaseQuestions
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var selectedAnswerIds: [String: String] = [:]
    @Published private(set) var isFinished: Bool = false
    @Published private(set) var quizPhase: QuizPhase = .family

    // Exposed so the host view can show the family-reveal transition card.
    @Published private(set) var identifiedFamily: SeasonFamily? = nil

    // MARK: - Private state

    private var posteriorHistory: [[String: Double]] = []
    private var familyAnswerCount: Int = 0  // tracks how many family-phase questions were answered

    let posterior: SharedPosterior
    private let paletteProvider: SeasonPaletteProviding
    private let scorer: QuestionnaireScoring

    init(
        posterior: SharedPosterior,
        paletteProvider: SeasonPaletteProviding = BundledSeasonPaletteProvider(),
        scorer: QuestionnaireScoring = BayesianSeasonScorer()
    ) {
        self.posterior = posterior
        self.paletteProvider = paletteProvider
        self.scorer = scorer
    }

    override func fetchData() async throws {
        let loaded = try paletteProvider.loadPalettes()
        posterior.palettes = loaded
        posterior.value = scorer.initialPosterior(palettes: loaded)
    }

    // MARK: - Derived

    var currentQuestion: QuizQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    // Progress within the current phase (0–1).
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    var rankedResults: [(name: String, probability: Double)] {
        posterior.rankedSeasons
    }

    var topSeasonName: String? { posterior.topSeasonName }
    var topConfidence: Double  { posterior.topConfidence }
    var canGoBack: Bool        { currentIndex > 0 }

    // MARK: - Answer

    func answer(_ answer: QuizAnswer) {
        guard let question = currentQuestion, !posterior.palettes.isEmpty else { return }
        posteriorHistory.append(posterior.value)
        selectedAnswerIds[question.id] = answer.id

        switch quizPhase {
        case .family:
            // Strip chroma so cross-family questions don't bias within-family variants.
            posterior.value = scorer.updateFamilyPhase(
                posterior: posterior.value,
                with: answer.likelihood,
                palettes: posterior.palettes
            )
            familyAnswerCount += 1
            logPosterior(stage: "Stage1-Family", label: "\(question.id)=\(answer.id)")
            advanceFamilyPhase()

        case .variant:
            // Collapsed posterior over 3 seasons — use full chroma-aware scorer.
            posterior.value = scorer.update(
                posterior: posterior.value,
                with: answer.likelihood,
                palettes: posterior.palettes
            )
            logPosterior(stage: "Stage1-Variant", label: "\(question.id)=\(answer.id)")
            advanceVariantPhase()
        }
    }

    // MARK: - Back / Restart

    func goBack() {
        guard canGoBack, !posteriorHistory.isEmpty else { return }
        posterior.value = posteriorHistory.removeLast()
        currentIndex -= 1
        selectedAnswerIds.removeValue(forKey: questions[currentIndex].id)
        isFinished = false

        if case .family = quizPhase { familyAnswerCount = max(0, familyAnswerCount - 1) }
    }

    func restart() {
        currentIndex = 0
        selectedAnswerIds = [:]
        posteriorHistory = []
        familyAnswerCount = 0
        quizPhase = .family
        identifiedFamily = nil
        posterior.identifiedFamily = nil
        questions = Stage1Questions.familyPhaseQuestions
        posterior.value = scorer.initialPosterior(palettes: posterior.palettes)
        isFinished = false
        errorMessage = nil
    }

    // MARK: - Phase transitions (private)

    private func advanceFamilyPhase() {
        let nextIndex = currentIndex + 1
        let allFamilyDone = nextIndex >= questions.count

        // Check if one family has reached the confidence threshold.
        let detectedFamily = SeasonFamily.dominantFamily(from: posterior.value)

        if let family = detectedFamily {
            // Family identified early — transition immediately.
            transitionToVariantPhase(family: family)
        } else if allFamilyDone {
            // Exhausted all family questions without threshold — pick top family.
            let topFamily = SeasonFamily.topFamily(from: posterior.value)
            transitionToVariantPhase(family: topFamily)
        } else {
            currentIndex = nextIndex
        }
    }

    private func advanceVariantPhase() {
        let nextIndex = currentIndex + 1
        if nextIndex >= questions.count {
            isFinished = true
        } else {
            currentIndex = nextIndex
        }
    }

    // Collapse the posterior to 3 seasons, store the family, load variant questions.
    private func transitionToVariantPhase(family: SeasonFamily) {
        posterior.value = family.collapse(posterior: posterior.value)
        posterior.identifiedFamily = family
        identifiedFamily = family
        quizPhase = .variant(family)
        questions = Stage1Questions.variantPhaseQuestions(for: family)
        currentIndex = 0
        logPosterior(stage: "Stage1-FamilyGate", label: "family=\(family.rawValue)")
    }

    // MARK: - Debug logging

    private func logPosterior(stage: String, label: String) {
#if DEBUG
        let top5 = posterior.rankedSeasons.prefix(5)
            .map { String(format: "%@ %.1f%%", $0.name, $0.probability * 100) }
            .joined(separator: " | ")
        print("[Blanch \(stage)] \(label) → \(top5)")
#endif
    }
}
