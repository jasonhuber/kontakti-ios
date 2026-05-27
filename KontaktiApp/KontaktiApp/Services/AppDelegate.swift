import UIKit
import UserNotifications

/// Bridges the SwiftUI App lifecycle to UIKit callbacks we need for APNs
/// and notification taps. Wired up via `@UIApplicationDelegateAdaptor` in
/// `KontaktiAppApp`.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Persisted hex APNs token (for later DELETE on logout / disable).
    static let tokenDefaultsKey = "kontakti.apns.token"
    /// Stable per-install identifier for push registration.
    static let deviceIdDefaultsKey = "kontakti.device.id"

    static var deviceId: String {
        let d = UserDefaults.standard
        if let id = d.string(forKey: deviceIdDefaultsKey) { return id }
        let id = UUID().uuidString
        d.set(id, forKey: deviceIdDefaultsKey)
        return id
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { await Self.requestAndRegister() }
        return true
    }

    /// Public helper so Settings → "Enable notifications" toggle can re-run this.
    static func requestAndRegister() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return }
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            // Permission failure — surface via Settings retry path.
            print("[Push] Authorization error: \(error)")
        }
    }

    /// Server registration. Called after APNs returns a device token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: Self.tokenDefaultsKey)
        Task {
            do {
                try await APIClient.shared.registerPushToken(
                    deviceToken: deviceToken,
                    deviceId: Self.deviceId
                )
            } catch {
                print("[Push] Backend register failed: \(error)")
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] APNs registration failed: \(error)")
        // Surface to user via Settings retry; for now we just log.
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Foreground presentation — show banner + sound while app is in front.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // A push almost always means today data changed — refresh the widget.
        NotificationCenter.default.post(name: .kontaktiTodayShouldRefresh, object: nil)
        completionHandler([.banner, .sound, .badge])
    }

    /// Notification tap. Routes deeplink payloads through DeepLinkRouter.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        if let deeplink = userInfo["deeplink"] as? String,
           let url = URL(string: deeplink),
           url.scheme?.lowercased() == "kontakti" {
            _ = DeepLinkRouter.shared.handle(url)
        }
    }
}
