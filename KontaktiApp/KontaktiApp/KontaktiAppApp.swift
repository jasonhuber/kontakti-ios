import SwiftUI
import SwiftData

@main
struct KontaktiAppApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(networkMonitor)
                .modelContainer(PersistenceController.shared.container)
                .task { await authVM.initialize() }
        }
    }
}
