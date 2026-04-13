import Foundation
import UIKit

// MARK: - Analysis ViewModel
// OOP Pattern: Inheritance (extends BaseViewModel) + Template Method
//
// Holds the state for the Analyze flow: selected photo, pipeline result,
// and submission status. The pipeline and repository are injected so the
// ViewModel stays testable — we can feed in a FakePipeline + FakeRepository
// in unit tests without touching Vision or the network.

@MainActor
final class AnalysisViewModel: BaseViewModel {
    @Published var selectedImage: UIImage?
    @Published var outcome: AnalysisOutcome?
    @Published var submittedResult: AnalysisResultOut?
    @Published var isSubmitting = false

    private let pipeline: AnalysisPipelining
    private let repository: AnalysisRepositoryProtocol

    init(pipeline: AnalysisPipelining, repository: AnalysisRepositoryProtocol) {
        self.pipeline = pipeline
        self.repository = repository
    }

    // Entry point: user picked a photo. Run the full pipeline but do not
    // auto-submit — the user confirms results first.
    func analyze(image: UIImage) async {
        selectedImage = image
        outcome = nil
        submittedResult = nil
        errorMessage = nil
        isLoading = true

        do {
            let pipelineOutcome = try await pipeline.run(on: image)
            outcome = pipelineOutcome
            hasLoaded = true
        } catch let error as FaceDetectionError {
            errorMessage = error.errorDescription
        } catch let error as SkinSamplerError {
            errorMessage = error.errorDescription
        } catch let error as AnalysisPipelineError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // User confirmed the result — POST to backend.
    func submit() async {
        guard let outcome else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            let result = try await repository.submit(outcome: outcome)
            submittedResult = result
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    func reset() {
        selectedImage = nil
        outcome = nil
        submittedResult = nil
        errorMessage = nil
    }
}
