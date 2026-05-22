import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var user: UserProfile?

    private let api = APIClient.shared
    private let keychain = KeychainService.shared

    func initialize() async {
        guard keychain.loadToken() != nil else {
            isLoading = false
            return
        }
        do {
            user = try await api.me()
            isAuthenticated = true
        } catch {
            keychain.deleteToken()
        }
        isLoading = false
    }

    func login(email: String, password: String) async throws {
        let response = try await api.login(email: email, password: password)
        keychain.saveToken(response.token)
        user = response.user
        isAuthenticated = true
    }

    func logout() async {
        try? await api.logout()
        keychain.deleteToken()
        user = nil
        isAuthenticated = false
    }
}
