import SwiftUI

struct ProductListView: View {
    @StateObject var viewModel: ProductListViewModel

    private let categories = ["All", "lipstick", "liner", "gloss", "blush", "tint"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search products...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task { await viewModel.search() }
                        }
                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                            Task { await viewModel.loadData() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.top, 8)

                // Category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { cat in
                            let isSelected = (cat == "All" && viewModel.selectedCategory == nil) ||
                                viewModel.selectedCategory == cat
                            Button {
                                Task {
                                    await viewModel.filterByCategory(cat == "All" ? nil : cat)
                                }
                            } label: {
                                Text(cat.capitalized)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Color.warmBrown : Color.warmBeige)
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                // Product list
                if viewModel.isLoading && viewModel.products.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(.warmBrown)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await viewModel.loadData() }
                        }
                        .buttonStyle(.bordered)
                        .tint(.warmBrown)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                        ], spacing: 16) {
                            ForEach(viewModel.products) { product in
                                ProductCard(product: product)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Discover")
            .task {
                if !viewModel.hasLoaded {
                    await viewModel.loadData()
                }
            }
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: ProductDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Color swatch
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: product.hexCode ?? "#CCCCCC"))
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.black.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(product.brand)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(product.shadeName ?? product.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack {
                    Text(product.category.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.warmBeige)
                        .clipShape(Capsule())

                    Spacer()

                    if let price = product.formattedPrice {
                        Text(price)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.warmBrown)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

// MARK: - Color Extension (hex support)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    // Warm organic palette (Rare Beauty inspired)
    static let warmBrown = Color(hex: "#8B6355")
    static let warmBeige = Color(hex: "#F5E6D3")
    static let warmIvory = Color(hex: "#FFF8F0")
    static let warmRose = Color(hex: "#D4847C")
    static let warmTerra = Color(hex: "#C4967A")
}
