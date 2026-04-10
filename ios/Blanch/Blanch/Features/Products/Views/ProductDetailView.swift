import SwiftUI

struct ProductDetailView: View {
    @StateObject var viewModel: ProductDetailViewModel

    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.product == nil {
                ProgressView()
                    .tint(.warmBrown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let product = viewModel.product {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Hero swatch
                        heroSwatch(product: product)

                        // Product info
                        productInfo(product: product)

                        // Shade picker
                        if viewModel.siblingShades.count > 1 {
                            shadePicker(currentId: product.id)
                        }

                        // Season matches
                        if !product.seasons.isEmpty {
                            seasonMatches(seasons: product.seasons)
                        }

                        // Action buttons
                        actionButtons(product: product)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !viewModel.hasLoaded {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Hero Swatch

    private func heroSwatch(product: ProductWithSeasons) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(hex: product.hexCode ?? "#CCCCCC"))
            .frame(height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal)
    }

    // MARK: - Product Info

    private func productInfo(product: ProductWithSeasons) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.brand)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(product.name)
                .font(.title2.weight(.bold))

            if let shade = product.shadeName {
                Text("Color: \(shade)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(product.category.capitalized)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.warmBeige)
                    .clipShape(Capsule())

                if let retailer = product.retailer {
                    Text(retailer.capitalized)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.warmIvory)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(Color.warmBeige, lineWidth: 1)
                        )
                }

                Spacer()

                if let cents = product.priceCents {
                    Text(String(format: "$%.2f", Double(cents) / 100.0))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.warmBrown)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Shade Picker

    private func shadePicker(currentId: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Available Shades")
                .font(.headline)
                .padding(.horizontal)

            // Swatch grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 10), count: 7), spacing: 10) {
                ForEach(viewModel.siblingShades) { shade in
                    Button {
                        viewModel.switchToShade(shade)
                    } label: {
                        Circle()
                            .fill(Color(hex: shade.hexCode ?? "#CCCCCC"))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .strokeBorder(shade.id == currentId ? Color.warmBrown : .clear, lineWidth: 3)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(.black.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)

            // Current shade name
            if let current = viewModel.siblingShades.first(where: { $0.id == currentId }) {
                Text(current.shadeName ?? current.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Season Matches

    private func seasonMatches(seasons: [ProductSeasonInfo]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Season Match")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(seasons.sorted(by: { $0.confidence > $1.confidence }), id: \.seasonId) { season in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(matchColor(confidence: season.confidence))

                        Text(season.seasonName)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        Text("\(Int(season.confidence * 100))% match")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.warmIvory)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(product: ProductWithSeasons) -> some View {
        VStack(spacing: 10) {
            if let urlString = product.affiliateUrl ?? product.productUrl,
               let url = URL(string: urlString) {
                Button {
                    openURL(url)
                } label: {
                    HStack {
                        Image(systemName: "bag.fill")
                        Text("View on \(product.retailer?.capitalized ?? "Retailer")")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.warmBrown)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func matchColor(confidence: Double) -> Color {
        if confidence > 0.6 { return .green }
        if confidence > 0.4 { return .orange }
        return .secondary
    }
}
