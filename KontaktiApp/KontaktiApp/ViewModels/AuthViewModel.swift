import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var needsOnboarding: Bool
    @Published var user: UserProfile?

    private let api = APIClient.shared
    private let keychain = KeychainService.shared
    private let onboardingKey = "kontakti_onboarded"

    init() {
        needsOnboarding = !UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func initialize() async {
        guard keychain.loadToken() != nil else {
            isLoading = false
            return
        }
        do {
            user = try await api.me()
            isAuthenticated = true
            await reconcileOnboardingStatus()
        } catch {
            if isUnauthorized(error) {
                keychain.deleteToken()
                isAuthenticated = false
            } else {
                // Keep the session for offline launches. Cached data can still be used.
                isAuthenticated = true
                if OfflineStore.shared.hasCachedData() {
                    markOnboardingCompleteLocally()
                }
            }
        }
        isLoading = false
    }

    func register(name: String, username: String, email: String, password: String) async throws {
        let response = try await api.register(name: name, username: username, email: email, password: password)
        keychain.saveToken(response.token)
        user = response.user
        isAuthenticated = true
        await reconcileOnboardingStatus()
    }

    func login(email: String, password: String) async throws {
        let response = try await api.login(email: email, password: password)
        keychain.saveToken(response.token)
        user = response.user
        isAuthenticated = true
        await reconcileOnboardingStatus()
    }

    func loginWithGoogle(presentingViewController: UIViewController) async throws {
        let googleTokens = try await GoogleAuthService.shared.signInTokens(presentingViewController: presentingViewController)
        let response = try await api.loginWithGoogle(idToken: googleTokens.idToken)
        keychain.saveToken(response.token)
        user = response.user
        isAuthenticated = true
        await reconcileOnboardingStatus()
    }

    func logout() async {
        try? await api.logout()
        GoogleAuthService.shared.signOut()
        keychain.deleteToken()
        OfflineStore.shared.clearAll()
        user = nil
        isAuthenticated = false
    }

    func completeOnboarding() {
        markOnboardingCompleteLocally()
        Task {
            if let updated = try? await api.completeOnboarding() {
                user = updated
            }
        }
    }

    private func reconcileOnboardingStatus() async {
        if isLocallyOnboarded() ||
            user?.hasCompletedOnboarding == true ||
            OfflineStore.shared.hasCachedData() {
            markOnboardingCompleteLocally()
            return
        }

        do {
            let firstPage = try await api.listPeople(page: 1)
            if firstPage.total > 0 {
                markOnboardingCompleteLocally()
                user = try? await api.completeOnboarding()
            } else {
                needsOnboarding = true
            }
        } catch {
            needsOnboarding = true
        }
    }

    private func markOnboardingCompleteLocally() {
        if let userId = user?.id {
            UserDefaults.standard.set(true, forKey: "\(onboardingKey)_\(userId)")
        }
        UserDefaults.standard.set(true, forKey: onboardingKey)
        needsOnboarding = false
    }

    private func isLocallyOnboarded() -> Bool {
        guard let userId = user?.id else {
            return UserDefaults.standard.bool(forKey: onboardingKey)
        }
        return UserDefaults.standard.bool(forKey: "\(onboardingKey)_\(userId)")
    }

    private func isUnauthorized(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        if case .unauthorized = apiError { return true }
        return false
    }
}
