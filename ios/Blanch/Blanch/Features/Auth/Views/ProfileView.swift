import SwiftUI

// MARK: - Profile View
//
// Shown in the Profile tab when the user is logged in. Basic info + logout.
// Also surfaces the current saved season from UserSession so the user can
// confirm their quiz result persisted.

struct ProfileView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var session: UserSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                seasonCard
                logoutButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.warmIvory.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Profile")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(authManager.currentUser?.displayName ?? "Signed in")
                .font(.largeTitle.weight(.bold))
            if let email = authManager.currentUser?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var seasonCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.warmBrown)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: session.currentSeasonName == nil ? "questionmark" : "sparkles")
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(session.currentSeasonName ?? "No season saved yet")
                    .font(.headline)
                if let confidence = session.currentConfidence {
                    Text("\(Int(confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Take the quiz to get personalized recommendations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.warmBeige, lineWidth: 1)
        )
    }

    private var logoutButton: some View {
        Button {
            authManager.logout()
        } label: {
            Text("Log out")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(Color.warmBrown)
    }
}
