import SwiftUI
import PhotosUI

// MARK: - Draping Capture View
//
// Entry point for Stage 2. Tells the user what's about to happen and
// hands off to the PhotosPicker. Once a photo is chosen, we kick the
// DrapingViewModel into its detect+render pipeline.

struct DrapingCaptureView: View {
    @ObservedObject var viewModel: DrapingViewModel
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                explainer
                guidelines
                pickerButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.warmIvory.ignoresSafeArea())
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await load(item: newItem) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step 2 of 2 — Draping")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("See shades on your own face")
                .font(.title2.weight(.bold))
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Traditional color analysts drape fabric against your face to confirm undertone. We do the same thing with lipstick — on YOUR selfie, in a few quick taps.")
                .font(.subheadline)
                .foregroundStyle(Color.primary)
            Text("You'll see two shades at a time. Pick the one that looks WORSE. Negative selection is faster and more reliable than picking favorites.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var guidelines: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("For best results")
                .font(.subheadline.weight(.semibold))
            ForEach(Self.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(Color.warmBrown)
                        .padding(.top, 6)
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.warmBeige.opacity(0.5))
        )
    }

    private var pickerButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            HStack {
                Image(systemName: "face.smiling")
                Text("Choose a selfie")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.warmBrown)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func load(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        await viewModel.startDraping(with: uiImage)
    }

    private static let tips = [
        "Face the camera straight on, lips neutral",
        "Natural daylight is ideal — no colored indoor lamps",
        "No existing lipstick, lip gloss, or strong lip tint",
        "Fill roughly half the frame with your face"
    ]
}
