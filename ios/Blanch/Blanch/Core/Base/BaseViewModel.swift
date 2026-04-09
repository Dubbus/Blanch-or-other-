import Foundation
import Combine

// MARK: - Base View Model
// OOP Patterns: Template Method + Observer
//
// Template Method: loadData() defines the SKELETON of the loading algorithm —
// set isLoading, call fetchData(), handle errors. Subclasses ONLY override
// fetchData() to provide their specific data fetching logic.
// The parent class controls the flow; the child class fills in the blank.
//
// Observer: @Published properties automatically notify SwiftUI views
// when they change. This is the Observer pattern built into Combine —
// the ViewModel is the Subject, the View is the Observer.

@MainActor
class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasLoaded = false

    // Template Method: subclasses override this
    func fetchData() async throws {
        // Default: no-op. Subclasses provide their specific fetch logic.
    }

    // Template Method: the fixed algorithm that calls fetchData()
    func loadData() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await fetchData()
            hasLoaded = true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Convenience: reload (force refresh)
    func reload() async {
        hasLoaded = false
        await loadData()
    }
}
