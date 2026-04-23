import SwiftUI

// MARK: - Questionnaire Host View
//
// Orchestrates the full quiz flow:
//   Stage 1 family questions → family reveal card → Stage 1 variant questions
//   → preliminary result → Stage 2 draping → final result
//
// Phase 3.6: added .familyReveal stage that fires when QuestionnaireViewModel
// transitions from .family to .variant phase.

struct QuestionnaireHostView: View {
    @StateObject var shared: SharedPosterior
    @StateObject var stage1VM: QuestionnaireViewModel
    @StateObject var drapingVM: DrapingViewModel

    @State private var stage: Stage = .stage1

    enum Stage: Equatable {
        case stage1
        case familyReveal(SeasonFamily)  // brief transition card between phases
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
                case .familyReveal(let family):
                    FamilyRevealCard(family: family) {
                        stage = .stage1
                    }
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
        .onChange(of: stage1VM.quizPhase) { old, new in
            // Fire the reveal card as soon as the VM transitions to variant phase.
            if case .variant(let family) = new, old == .family, stage == .stage1 {
                stage = .familyReveal(family)
            }
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
        case .stage1, .familyReveal: return "Color Quiz"
        case .stage1Result:          return "Color Quiz"
        case .stage2:                return "Draping"
        case .finalResult:           return "Your Result"
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
        case .tiebreaker:
            if let pair = drapingVM.tiebreakerPair {
                DrapingPairView(viewModel: drapingVM, pair: pair)
            } else {
                ProgressView().controlSize(.large)
            }
        case .finished:
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

// MARK: - Family Reveal Card

private struct FamilyRevealCard: View {
    let family: SeasonFamily
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("You're reading as a")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(family.displayName)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.warmBrown)

                Text(family.revealTagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.warmBrown)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                appeared = true
            }
        }
    }
}

// MARK: - Stage 1 single-question screen

private struct Stage1QuestionView: View {
    @ObservedObject var viewModel: QuestionnaireViewModel
    let question: QuizQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            progressBar
            phaseLabel
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewModel.canGoBack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.goBack()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.footnote.weight(.semibold))
                            Text("Back")
                                .font(.body)
                        }
                        .foregroundStyle(Color.warmBrown)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var phaseLabel: some View {
        if case .variant(let family) = viewModel.quizPhase {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.warmBrown)
                Text("\(family.displayName) identified — fine-tuning")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.warmBrown)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.warmBrown.opacity(0.1))
            )
        }
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
