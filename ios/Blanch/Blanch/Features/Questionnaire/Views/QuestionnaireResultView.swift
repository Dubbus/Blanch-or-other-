import SwiftUI

// MARK: - Questionnaire Result View (Stage 1 interstitial)
//
// Shown after the four factual questions finish, before Stage 2 draping.
// Framed explicitly as a "preliminary read" so the draping step feels
// like a confirmation rather than redundant work. Two exits:
//   • Continue → Stage 2 draping on a selfie
//   • Start over → reset Stage 1

struct QuestionnaireResultView: View {
    @ObservedObject var viewModel: QuestionnaireViewModel
    let onContinue: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                topCard
                breakdown
                continueButton
                retryButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preliminary read")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Based on your answers")
                .font(.title2.weight(.semibold))
            Text("This is a rough family call. Next we'll confirm it by draping actual lipstick shades on your own face.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var topCard: some View {
        if let top = viewModel.rankedResults.first {
            HStack(alignment: .center, spacing: 14) {
                Circle()
                    .fill(Color.warmBrown)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(initials(for: top.name))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(top.name)
                        .font(.title3.weight(.bold))
                    Text("\(Int(top.probability * 100))% confidence")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.warmBeige, lineWidth: 1)
            )
        }
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Full ranking")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(viewModel.rankedResults.prefix(6), id: \.name) { entry in
                seasonRow(name: entry.name, probability: entry.probability)
            }
        }
    }

    private func seasonRow(name: String, probability: Double) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.warmBeige)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.warmBrown)
                        .frame(width: geo.size.width * CGFloat(probability))
                }
            }
            .frame(height: 6)
            Text("\(Int(probability * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Image(systemName: "face.smiling")
                Text("Continue with a selfie")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.warmBrown)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 8)
    }

    private var retryButton: some View {
        Button(action: onRestart) {
            Text("Start over")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(Color.warmBrown)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
