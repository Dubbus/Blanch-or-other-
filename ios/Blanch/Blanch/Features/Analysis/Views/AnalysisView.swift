import SwiftUI
import PhotosUI

// MARK: - Analysis View
// Root view for the Analyze tab. Handles three states:
//   1. Start — lighting guidelines + "Choose photo" button
//   2. Analyzing — progress indicator overlaid on the selected photo
//   3. Result — detected face, sampled skin swatch, top season, confirm/retake

struct AnalysisView: View {
    @StateObject var viewModel: AnalysisViewModel
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.warmIvory.ignoresSafeArea()
                content
            }
            .navigationTitle("Color Analysis")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadAndAnalyze(newItem) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let result = viewModel.submittedResult {
            AnalysisSubmittedView(result: result) {
                viewModel.reset()
                pickerItem = nil
            }
        } else if let outcome = viewModel.outcome, let image = viewModel.selectedImage {
            AnalysisResultView(
                image: image,
                outcome: outcome,
                isSubmitting: viewModel.isSubmitting,
                errorMessage: viewModel.errorMessage,
                onSubmit: { Task { await viewModel.submit() } },
                onRetake: {
                    viewModel.reset()
                    pickerItem = nil
                }
            )
        } else if viewModel.isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.warmBrown)
                Text("Analyzing your photo…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            AnalysisStartView(
                errorMessage: viewModel.errorMessage,
                pickerItem: $pickerItem
            )
        }
    }

    private func loadAndAnalyze(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await viewModel.analyze(image: image)
            }
        } catch {
            viewModel.errorMessage = "Couldn't load that photo: \(error.localizedDescription)"
        }
    }
}

// MARK: - Start state (lighting guidelines + picker)

private struct AnalysisStartView: View {
    let errorMessage: String?
    @Binding var pickerItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroHeader

                LightingGuidelinesCard()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Choose a photo")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.warmBrown)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find your color season")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.warmBrown)
            Text("Upload a well-lit selfie and we'll match you to one of 12 color seasons. Good lighting is essential — see the tips below before you pick a photo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Lighting guidelines card

private struct LightingGuidelinesCard: View {
    private struct Tip: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let tips: [Tip] = [
        Tip(icon: "sun.max.fill",       title: "Natural daylight",  detail: "Stand near a window. Avoid direct sun — diffused daylight is best."),
        Tip(icon: "lightbulb.slash",    title: "No colored lighting", detail: "Yellow indoor bulbs, LEDs, and sunset light skew the reading."),
        Tip(icon: "face.smiling",       title: "Clean, bare face",  detail: "Remove makeup, foundation, and tinted moisturizer before the photo."),
        Tip(icon: "camera.metering.center.weighted", title: "Face the light", detail: "Light should come from in front of you, not from above or behind."),
        Tip(icon: "rectangle.center.inset.filled",   title: "Fill the frame",  detail: "Your whole face should be visible and roughly centered.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.warmRose)
                Text("For accurate results")
                    .font(.headline)
                    .foregroundStyle(Color.warmBrown)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(tips) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: tip.icon)
                            .font(.title3)
                            .foregroundStyle(Color.warmTerra)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title)
                                .font(.subheadline.weight(.semibold))
                            Text(tip.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.warmBeige.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Result view (before submission)

private struct AnalysisResultView: View {
    let image: UIImage
    let outcome: AnalysisOutcome
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: () -> Void
    let onRetake: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AnnotatedPhoto(image: image, outcome: outcome)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                SkinSwatchSummary(sample: outcome.skinSample)

                TopSeasonsList(classification: outcome.classification)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 10) {
                    Button(action: onSubmit) {
                        HStack {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(isSubmitting ? "Saving…" : "Save this result")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.warmBrown)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isSubmitting)

                    Button("Try another photo", action: onRetake)
                        .font(.subheadline)
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .padding()
        }
    }
}

// MARK: - Annotated photo (image + face box overlay)

private struct AnnotatedPhoto: View {
    let image: UIImage
    let outcome: AnalysisOutcome

    var body: some View {
        // Lock the container to the image's aspect ratio so there's no
        // letterboxing — then the face box maps proportionally by simple
        // fraction-of-container math and coordinate systems line up exactly.
        Image(uiImage: image)
            .resizable()
            .aspectRatio(outcome.imageSize, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let scaleX = geo.size.width / outcome.imageSize.width
                    let scaleY = geo.size.height / outcome.imageSize.height
                    Rectangle()
                        .stroke(Color.warmRose, lineWidth: 2)
                        .frame(
                            width: outcome.faceBox.width * scaleX,
                            height: outcome.faceBox.height * scaleY
                        )
                        .position(
                            x: (outcome.faceBox.midX) * scaleX,
                            y: (outcome.faceBox.midY) * scaleY
                        )
                }
            }
            .background(Color.warmBeige.opacity(0.4))
    }
}

// MARK: - Skin swatch

private struct SkinSwatchSummary: View {
    let sample: SkinSample

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(lab: sample.averageLAB))
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.warmBrown.opacity(0.15), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Your sampled skin tone")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.warmBrown)
                Text("\(sample.regions.count) regions • \(sample.pixelsUsed.formatted()) pixels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "L %.1f  a %.1f  b %.1f", sample.averageLAB.l, sample.averageLAB.a, sample.averageLAB.b))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.warmIvory)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.warmBrown.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Top seasons ranked list

private struct TopSeasonsList: View {
    let classification: SeasonClassification

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top matches")
                .font(.headline)
                .foregroundStyle(Color.warmBrown)

            let ranked = classification.ranked.prefix(3)
            ForEach(Array(ranked.enumerated()), id: \.offset) { index, entry in
                HStack {
                    Text("\(index + 1). \(entry.name)")
                        .font(.subheadline.weight(index == 0 ? .bold : .regular))
                        .foregroundStyle(index == 0 ? Color.warmBrown : .primary)
                    Spacer()
                    Text(String(format: "%.0f%%", entry.score * 100))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(index == 0 ? Color.warmBeige.opacity(0.6) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color.warmIvory)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.warmBrown.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Submitted confirmation

private struct AnalysisSubmittedView: View {
    let result: AnalysisResultOut
    let onAnalyzeAgain: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.warmRose)

            Text("You're a \(result.season.name)")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.warmBrown)
                .multilineTextAlignment(.center)

            if let description = result.season.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 8) {
                ForEach(result.season.hexPalette.prefix(8), id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.warmBrown.opacity(0.15), lineWidth: 1))
                }
            }

            Button("Analyze another photo", action: onAnalyzeAgain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.warmBrown)
                .clipShape(Capsule())
                .padding(.top, 8)
        }
        .padding()
    }
}

// MARK: - Color from LAB (for the swatch)

private extension Color {
    init(lab: LAB) {
        // Quick-and-dirty LAB → sRGB approximation for the UI swatch.
        // We invert the same transform ColorSpaceConverter uses. For a visual
        // swatch this is accurate enough — values are clamped to display range.
        let y = (lab.l + 16.0) / 116.0
        let x = lab.a / 500.0 + y
        let z = y - lab.b / 200.0

        func labFInverse(_ t: Double) -> Double {
            let cube = t * t * t
            return cube > 0.008856 ? cube : (t - 16.0 / 116.0) / 7.787
        }

        let X = 95.047  * labFInverse(x) / 100.0
        let Y = 100.000 * labFInverse(y) / 100.0
        let Z = 108.883 * labFInverse(z) / 100.0

        var r =  X * 3.2406 + Y * -1.5372 + Z * -0.4986
        var g =  X * -0.9689 + Y * 1.8758 + Z * 0.0415
        var b =  X * 0.0557 + Y * -0.2040 + Z * 1.0570

        func companding(_ v: Double) -> Double {
            let clamped = max(0.0, min(1.0, v))
            return clamped > 0.0031308
                ? 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
                : 12.92 * clamped
        }
        r = companding(r); g = companding(g); b = companding(b)
        self.init(red: r, green: g, blue: b)
    }
}
