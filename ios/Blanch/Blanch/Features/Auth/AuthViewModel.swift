import Foundation

// MARK: - Auth ViewModel
//
// Drives the sign-in / register form. Toggle `mode` between .login and
// .register; the view conditionally shows the display-name field. On
// submit, calls the repo then hands the resulting session to AuthManager.

@MainActor
final class AuthViewModel: BaseViewModel {
    enum Mode: Sendable, CaseIterable {
        case login, register

        var title: String {
            switch self {
            case .login: return "Welcome back"
            case .register: return "Create account"
            }
        }

        var cta: String {
            switch self {
            case .login: return "Log in"
            case .register: return "Create account"
            }
        }

        var toggleLabel: String {
            switch self {
            case .login: return "New here? Create an account"
            case .register: return "Already have an account? Log in"
            }
        }
    }

    @Published var mode: Mode = .login
    @Published var email: String = ""
    @Published var displayName: String = ""
    @Published var password: String = ""
    @Published private(set) var isSubmitting: Bool = false

    private let repository: AuthRepositoryProtocol
    private let authManager: AuthManager

    init(repository: AuthRepositoryProtocol, authManager: AuthManager) {
        self.repository = repository
        self.authManager = authManager
    }

    var canSubmit: Bool {
        let emailOk = email.contains("@") && email.contains(".")
        let passwordOk = password.count >= 6
        let nameOk = mode == .login || !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        return emailOk && passwordOk && nameOk && !isSubmitting
    }

    func toggleMode() {
        mode = (mode == .login) ? .register : .login
        errorMessage = nil
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            let response: AuthResponse
            switch mode {
            case .login:
                response = try await repository.login(email: email, password: password)
            case .register:
                response = try await repository.register(
                    email: email,
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
            authManager.setSession(token: response.accessToken, user: response.user)
            password = ""
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
