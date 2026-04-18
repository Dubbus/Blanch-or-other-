import SwiftUI

// MARK: - Sign In View
//
// Combined login + register form with a mode toggle. Two fields for login
// (email, password); adds display name for register. Submit button is
// disabled until the fields validate client-side.

struct SignInView: View {
    @StateObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case email, displayName, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                fields
                submitButton
                toggleModeButton
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.warmIvory.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Blanch")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.warmBrown)
            Text(viewModel.mode.title)
                .font(.largeTitle.weight(.bold))
            Text("Your color season + matched products, saved across sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var fields: some View {
        VStack(spacing: 12) {
            field(
                icon: "envelope",
                placeholder: "Email",
                text: $viewModel.email,
                isSecure: false,
                keyboard: .emailAddress,
                focus: .email,
                next: viewModel.mode == .register ? .displayName : .password
            )

            if viewModel.mode == .register {
                field(
                    icon: "person",
                    placeholder: "Display name",
                    text: $viewModel.displayName,
                    isSecure: false,
                    keyboard: .default,
                    focus: .displayName,
                    next: .password
                )
            }

            field(
                icon: "lock",
                placeholder: "Password (6+ characters)",
                text: $viewModel.password,
                isSecure: true,
                keyboard: .default,
                focus: .password,
                next: nil
            )
        }
    }

    private func field(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        keyboard: UIKeyboardType,
        focus: Field,
        next: Field?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.warmBrown)
                .frame(width: 20)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                        .autocorrectionDisabled(keyboard == .emailAddress)
                }
            }
            .focused($focusedField, equals: focus)
            .submitLabel(next == nil ? .go : .next)
            .onSubmit {
                if let next {
                    focusedField = next
                } else {
                    Task { await viewModel.submit() }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.warmBeige, lineWidth: 1)
        )
    }

    private var submitButton: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSubmitting {
                    ProgressView().tint(.white)
                }
                Text(viewModel.isSubmitting ? "Working…" : viewModel.mode.cta)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.canSubmit ? Color.warmBrown : Color.warmBrown.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!viewModel.canSubmit)
    }

    private var toggleModeButton: some View {
        Button(action: { viewModel.toggleMode() }) {
            Text(viewModel.mode.toggleLabel)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .tint(Color.warmBrown)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}
