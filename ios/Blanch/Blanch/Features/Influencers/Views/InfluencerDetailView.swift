import SwiftUI

struct InfluencerDetailView: View {
    let influencer: InfluencerDTO

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar + name header
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.warmBeige)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Text(String(influencer.displayName?.prefix(1) ?? "?"))
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Color.warmBrown)
                        )

                    Text(influencer.displayName ?? influencer.handle)
                        .font(.title2.weight(.bold))

                    Text(influencer.handle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let bio = influencer.bio {
                        Text(bio)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    HStack(spacing: 16) {
                        Label(influencer.formattedFollowers, systemImage: "person.2.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(influencer.platform.capitalized)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.warmBeige)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 8)

                // Social links
                VStack(spacing: 12) {
                    if let instagramUrl = influencer.instagramUrl,
                       let url = URL(string: instagramUrl) {
                        SocialLinkButton(
                            title: "Instagram",
                            subtitle: influencer.handle.replacingOccurrences(of: "@", with: ""),
                            iconName: "camera.fill",
                            color: Color(red: 0.88, green: 0.27, blue: 0.40),
                            url: url
                        )
                    }

                    if let tiktokUrl = influencer.tiktokUrl,
                       let url = URL(string: tiktokUrl) {
                        SocialLinkButton(
                            title: "TikTok",
                            subtitle: influencer.handle,
                            iconName: "play.rectangle.fill",
                            color: .black,
                            url: url
                        )
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Social Link Button

struct SocialLinkButton: View {
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
    let url: URL

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}
