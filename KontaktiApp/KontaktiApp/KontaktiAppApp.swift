import SwiftUI
import SwiftData
import Combine

@main
struct KontaktiAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var deepLink = DeepLinkRouter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(networkMonitor)
                .environmentObject(deepLink)
                .modelContainer(PersistenceController.shared.container)
                .task { await authVM.initialize() }
                .task {
                    guard AppleContactLinkBackup.isEnabled else { return }
                    await OfflineStore.shared.restoreAppleContactLinksFromCloud()
                }
                .onReceive(networkMonitor.$isConnected.removeDuplicates()) { isConnected in
                    guard isConnected, authVM.isAuthenticated else { return }
                    Task { await SyncQueue.shared.flush() }
                }
                .onOpenURL { url in
                    if url.scheme?.lowercased() == "kontakti" {
                        _ = deepLink.handle(url)
                    } else {
                        _ = GoogleAuthService.shared.handleOpenURL(url)
                    }
                }
        }
    }
}
