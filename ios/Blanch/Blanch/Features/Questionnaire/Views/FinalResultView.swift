import SwiftUI

// MARK: - Final Result View
//
// Terminal screen after Stage 2 draping. Reads the COMBINED posterior
// (Stage 1 factual answers × Stage 2 A/B draping) from SharedPosterior.
// Shows the top season, confidence, and a ranking. This is the result
// we'd eventually submit to the backend as the user's color season.

struct FinalResultView: View {
    @ObservedObject var shared: SharedPosterior
    @ObservedObject var drapingVM: DrapingViewModel
    let explanation: ResultExplanation
    let onRestart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                selfieWithTopShade
                topCard
                saveSection
                whyCard
                breakdown
                footnote
                restartButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Why this season?

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(Color.warmBrown)
                Text("Why this season?")
                    .font(.subheadline.weight(.semibold))
            }

            Text(explanation.headline)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            axisBar(label: "Undertone", leftLabel: "Cool", rightLabel: "Warm", score: explanation.undertoneScore)
            axisBar(label: "Depth", leftLabel: "Light", rightLabel: "Deep", score: explanation.depthScore)

            if !explanation.reasons.isEmpty {
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(explanation.reasons) { reason in
                        reasonRow(reason)
                    }
                }
            }
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

    // Axis bar: score is -1..+1. Marker position maps linearly to that range.
    private func axisBar(label: String, leftLabel: String, rightLabel: String, score: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.warmBeige)
                    let normalized = (score + 1.0) / 2.0        // 0...1
                    let clamped = max(0.02, min(0.98, normalized))
                    Circle()
                        .fill(Color.warmBrown)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: geo.size.width * clamped - 7)
                }
            }
            .frame(height: 14)
            HStack {
                Text(leftLabel).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(rightLabel).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func reasonRow(_ reason: ExplainerReason) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: reason.icon)
                .foregroundStyle(iconTint(reason.direction))
                .frame(width: 18)
                .padding(.top, 2)
            Text(reason.text)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func iconTint(_ direction: Direction) -> Color {
        switch direction {
        case .warm, .deep: return Color.warmBrown
        case .cool, .light: return Color.warmTerra
        case .neutral: return Color.secondary
        }
    }

    @ViewBuilder
    private var saveSection: some View {
        if drapingVM.isSubmitted {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved")
                        .font(.subheadline.weight(.semibold))
                    Text("Check the Discover tab for your matched products.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.green.opacity(0.12))
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await drapingVM.submit() }
                } label: {
                    HStack(spacing: 8) {
                        if drapingVM.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "bookmark.fill")
                        }
                        Text(drapingVM.isSubmitting ? "Saving…" : "Save my result")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.warmBrown)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(drapingVM.isSubmitting)

                if let error = drapingVM.submitError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your season")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let name = shared.topSeasonName {
                Text(name)
                    .font(.largeTitle.weight(.bold))
            }
            Text("\(Int(shared.topConfidence * 100))% confidence — combined from quiz + draping")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // Show the user's selfie with the most-flattering shade they picked
    // during Stage 2 draping. Fallback to any rendered image if we can't
    // identify the "last winner".
    @ViewBuilder
    private var selfieWithTopShade: some View {
        if let lastWinId = drapingVM.pickedShadeIds.last,
           let image = drapingVM.renderedImages[lastWinId] {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.warmBeige, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var topCard: some View {
        if let top = shared.rankedSeasons.first {
            HStack(alignment: .center, spacing: 14) {
                Circle()
                    .fill(Color.warmBrown)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(initials(for: top.name))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(top.name).font(.title3.weight(.bold))
                    Text("Primary match").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(top.probability * 100))%")
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.warmBrown)
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
            ForEach(shared.rankedSeasons.prefix(6), id: \.name) { entry in
                row(name: entry.name, probability: entry.probability)
            }
        }
    }

    private func row(name: String, probability: Double) -> some View {
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

    @ViewBuilder
    private var footnote: some View {
        if drapingVM.usedHeuristicLipRegion {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Ran on approximate lip position (simulator fallback). On a real device we use Vision face landmarks for a precise fit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.warmBeige.opacity(0.4))
            )
        }
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            Text("Start over")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(Color.warmBrown)
        .padding(.top, 8)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
