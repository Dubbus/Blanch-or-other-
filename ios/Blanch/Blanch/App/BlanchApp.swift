import SwiftUI

@main
struct BlanchApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            coordinator.rootView()
                .environmentObject(coordinator)
        }
    }
}
