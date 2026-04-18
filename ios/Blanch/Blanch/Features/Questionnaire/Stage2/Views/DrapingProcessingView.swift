import SwiftUI

// MARK: - Draping Processing View
//
// Interstitial shown while the VM detects lip region and renders all
// catalog shades. Typically 2-4s on sim with heuristic fallback; ~1s
// on device with real landmarks.

struct DrapingProcessingView: View {
    @ObservedObject var viewModel: DrapingViewModel

    var body: some View {
        VStack(spacing: 20) {
            if let selfie = viewModel.selfie {
                Image(uiImage: selfie)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.warmBeige, lineWidth: 1)
                    )
            }
            ProgressView()
                .controlSize(.large)
                .tint(Color.warmBrown)
            Text("Detecting lips and applying shades…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
