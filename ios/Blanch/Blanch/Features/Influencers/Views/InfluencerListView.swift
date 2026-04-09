import SwiftUI

struct InfluencerListView: View {
    @StateObject var viewModel: InfluencerListViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.influencers.isEmpty {
                    ProgressView()
                        .tint(.warmBrown)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.influencers) { influencer in
                                InfluencerCard(influencer: influencer)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Influencers")
            .task {
                if !viewModel.hasLoaded {
                    await viewModel.loadData()
                }
            }
        }
    }
}

// MARK: - Influencer Card

struct InfluencerCard: View {
    let influencer: InfluencerDTO

    var body: some View {
        HStack(spacing: 14) {
            // Avatar placeholder
            Circle()
                .fill(Color.warmBeige)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String(influencer.displayName?.prefix(1) ?? "?"))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.warmBrown)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(influencer.displayName ?? influencer.handle)
                    .font(.headline)

                Text(influencer.handle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label(influencer.formattedFollowers, systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(influencer.platform.capitalized)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.warmBeige)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }
}
