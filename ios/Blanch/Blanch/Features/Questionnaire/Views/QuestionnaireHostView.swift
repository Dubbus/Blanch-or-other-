import SwiftUI

// MARK: - Questionnaire Host View
//
// Orchestrates the full quiz flow: Stage 1 (factual questions) →
// Stage 2 (draping A/B on user's selfie) → combined result.
//
// Owns both Stage 1 and Stage 2 ViewModels plus the SharedPosterior
// they both mutate. Routes based on `stage` state.

struct QuestionnaireHostView: View {
    @StateObject var shared: SharedPosterior
    @StateObject var stage1VM: QuestionnaireViewModel
    @StateObject var drapingVM: DrapingViewModel

    @State private var stage: Stage = .stage1

    enum Stage {
        case stage1
        case stage1Result
        case stage2
        case finalResult
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .stage1:
                    stage1Screen
                case .stage1Result:
                    QuestionnaireResultView(
                        viewModel: stage1VM,
                        onContinue: { stage = .stage2 },
                        onRestart: {
                            stage1VM.restart()
                            stage = .stage1
                        }
                    )
                case .stage2:
                    stage2Screen
                case .finalResult:
                    FinalResultView(
                        shared: shared,
                        drapingVM: drapingVM,
                        explanation: explanation(),
                        onRestart: {
                            drapingVM.restart()
                            stage1VM.restart()
                            stage = .stage1
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.warmIvory.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if !stage1VM.hasLoaded { await stage1VM.loadData() }
        }
        .onChange(of: stage1VM.isFinished) { _, finished in
            if finished, stage == .stage1 { stage = .stage1Result }
        }
        .onChange(of: drapingVM.phase) { _, phase in
            if case .finished = phase { stage = .finalResult }
        }
    }

    private func explanation() -> ResultExplanation {
        ResultExplainer().explain(
            selectedAnswerIds: stage1VM.selectedAnswerIds,
            pickedShadeIds: drapingVM.pickedShadeIds,
            topSeasonName: shared.topSeasonName ?? ""
        )
    }

    private var title: String {
        switch stage {
        case .stage1, .stage1Result: return "Color Quiz"
        case .stage2: return "Draping"
        case .finalResult: return "Your Result"
        }
    }

    @ViewBuilder
    private var stage1Screen: some View {
        if stage1VM.isLoading {
            ProgressView().controlSize(.large)
        } else if let error = stage1VM.errorMessage {
            errorBanner(error, retry: { Task { await stage1VM.reload() } })
        } else if let question = stage1VM.currentQuestion {
            Stage1QuestionView(viewModel: stage1VM, question: question)
        } else {
            ProgressView().controlSize(.large)
        }
    }

    @ViewBuilder
    private var stage2Screen: some View {
        switch drapingVM.phase {
        case .idle:
            DrapingCaptureView(viewModel: drapingVM)
        case .processing:
            DrapingProcessingView(viewModel: drapingVM)
        case .pairing:
            if let pair = drapingVM.currentPair {
                DrapingPairView(viewModel: drapingVM, pair: pair)
            } else {
                ProgressView().controlSize(.large)
            }
        case .finished:
            // Auto-transition is handled by onChange; show loader briefly.
            ProgressView().controlSize(.large)
        }
    }

    private func errorBanner(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(Color.warmBrown)
        }
    }
}

// MARK: - Stage 1 single-question screen
// Extracted from the old QuestionnaireView so the host can embed it.

private struct Stage1QuestionView: View {
    @ObservedObject var viewModel: QuestionnaireViewModel
    let question: QuizQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            progressBar
            VStack(alignment: .leading, spacing: 10) {
                Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(question.prompt)
                    .font(.title2.weight(.semibold))
                if let helper = question.helperText {
                    Text(helper)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 12) {
                ForEach(question.options) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.answer(option)
                        }
                    } label: {
                        optionCard(option)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func optionCard(_ option: QuizAnswer) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                if let detail = option.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.warmBeige, lineWidth: 1)
        )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.warmBeige)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.warmBrown)
                    .frame(width: geo.size.width * CGFloat(viewModel.progress))
            }
        }
        .frame(height: 6)
    }
}
