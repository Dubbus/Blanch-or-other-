import SwiftUI

// MARK: - Draping Pair View
//
// Presents a single A/B forced-choice. The two rendered lip previews of
// the user's own selfie are stacked vertically for clarity — side-by-side
// at phone width makes the lips too small to read.
//
// Tapping either card advances to the next pair; the VM applies the WINNER
// (i.e., the OTHER shade) to the posterior, since the prompt is negative.

struct DrapingPairView: View {
    @ObservedObject var viewModel: DrapingViewModel
    let pair: DrapingPair

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressHeader
            prompt
            optionCard(image: viewModel.renderedImages[pair.shadeA.id], shade: pair.shadeA, other: pair.shadeB, label: "A")
            optionCard(image: viewModel.renderedImages[pair.shadeB.id], shade: pair.shadeB, other: pair.shadeA, label: "B")
            helperText
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pair \(viewModel.currentIndex + 1) of \(viewModel.totalPairCount)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                if pair.isTiebreaker {
                    Text("Final Call")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.warmBrown))
                }
            }
            GeometryReader { geo in
                let totalPairs = max(viewModel.totalPairCount, 1)
                let fraction = CGFloat(viewModel.currentIndex) / CGFloat(totalPairs)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.warmBeige)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.warmBrown)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }

    private var prompt: some View {
        Text(pair.prompt)
            .font(.title3.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func optionCard(image: UIImage?, shade: DrapingShade, other: DrapingShade, label: String) -> some View {
        // Negative framing: tapping this card means this shade looks bad → the OTHER shade wins.
        // Positive framing (tiebreaker): tapping this card means this shade is preferred → THIS shade wins.
        let winner = pair.isTiebreaker ? shade : other
        let rejected = pair.isTiebreaker ? other : shade
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.pick(shade: winner, rejected: rejected)
            }
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.warmBrown))

                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.warmBeige
                    }
                }
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(shade.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    HStack(spacing: 6) {
                        Circle().fill(shade.color).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                        Text(shade.hex.uppercased())
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.warmBeige, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var helperText: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(pair.isTiebreaker
                ? "Tap whichever shade feels most like you. Your pick breaks the tie."
                : "Tap whichever shade makes your face look worse. Negative selection — we score the other one as a win."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
