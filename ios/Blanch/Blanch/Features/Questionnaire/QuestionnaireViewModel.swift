import Foundation

// MARK: - Questionnaire ViewModel
// OOP Patterns: Inheritance (BaseViewModel) + Template Method + Strategy
//
// Drives the Stage-1 quiz: loads palettes once, walks through a list of
// questions, and maintains a live posterior over the 12 seasons via the
// SharedPosterior reference type so Stage 2 (draping) can pick up the
// same distribution and keep updating it.

@MainActor
final class QuestionnaireViewModel: BaseViewModel {
    @Published private(set) var questions: [QuizQuestion] = Stage1Questions.all
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var selectedAnswerIds: [String: String] = [:]
    @Published private(set) var isFinished: Bool = false

    let posterior: SharedPosterior

    private let paletteProvider: SeasonPaletteProviding
    private let scorer: QuestionnaireScoring

    // Stage 1 alone can't reach high confidence (weights are deliberately
    // mild). Early-stop threshold is never realistically hit here — it's
    // kept so the ViewModel remains usable if we later add stronger Stage 1
    // questions.
    private let earlyStopThreshold: Double = 0.55

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

    var currentQuestion: QuizQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    var rankedResults: [(name: String, probability: Double)] {
        posterior.rankedSeasons
    }

    var topSeasonName: String? {
        posterior.topSeasonName
    }

    var topConfidence: Double {
        posterior.topConfidence
    }

    func answer(_ answer: QuizAnswer) {
        guard let question = currentQuestion, !posterior.palettes.isEmpty else { return }
        selectedAnswerIds[question.id] = answer.id
        posterior.value = scorer.update(
            posterior: posterior.value,
            with: answer.likelihood,
            palettes: posterior.palettes
        )

        if currentIndex + 1 >= questions.count || topConfidence >= earlyStopThreshold {
            isFinished = true
        } else {
            currentIndex += 1
        }
    }

    func restart() {
        currentIndex = 0
        selectedAnswerIds = [:]
        posterior.value = scorer.initialPosterior(palettes: posterior.palettes)
        isFinished = false
        errorMessage = nil
    }
}
