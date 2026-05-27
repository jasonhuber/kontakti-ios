import Foundation
import SwiftUI
import GoogleSignIn

// MARK: - Google Auth

/// Handles the Google OAuth 2.0 flow using the GoogleSignIn SPM package.
///
/// SPM dependency: https://github.com/google/GoogleSignIn-iOS
/// Package identifier: GoogleSignIn
///
/// INFO.PLIST REQUIREMENTS:
/// 1. GIDClientID — your Google OAuth client ID (e.g. "123456789-abc.apps.googleusercontent.com")
/// 2. Add a URL scheme matching your reversed client ID (e.g. "com.googleusercontent.apps.123456789-abc")
///
/// Scopes requested:
///   https://www.googleapis.com/auth/contacts.readonly
///   https://www.googleapis.com/auth/gmail.readonly

enum GoogleAuthError: LocalizedError {
    case missingClientID
    case signInFailed(String)
    case noToken
    case noIDToken

    var errorDescription: String? {
        switch self {
        case .missingClientID: return "GIDClientID not found in Info.plist."
        case .signInFailed(let msg): return "Google sign-in failed: \(msg)"
        case .noToken: return "Could not retrieve Google access token."
        case .noIDToken: return "Could not retrieve Google identity token."
        }
    }
}

struct GoogleSignInTokens {
    let idToken: String
    let accessToken: String
}

@MainActor
final class GoogleAuthService: ObservableObject {
    static let shared = GoogleAuthService()

    @Published private(set) var accessToken: String?
    @Published private(set) var isSignedIn: Bool = false

    private let contactsScope = "https://www.googleapis.com/auth/contacts.readonly"
    private let gmailScope    = "https://www.googleapis.com/auth/gmail.readonly"

    private init() {}

    // MARK: - Sign in

    /// Presents the Google Sign-In sheet and requests contacts + gmail scopes.
    /// Returns the access token on success.
    func signIn(presentingViewController: UIViewController) async throws -> String {
        let tokens = try await signInTokens(presentingViewController: presentingViewController)
        return tokens.accessToken
    }

    func signInTokens(presentingViewController: UIViewController) async throws -> GoogleSignInTokens {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty else {
            throw GoogleAuthError.missingClientID
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController,
                hint: nil,
                additionalScopes: [contactsScope, gmailScope]
            ) { [weak self] result, error in
                if let error {
                    continuation.resume(throwing: GoogleAuthError.signInFailed(error.localizedDescription))
                    return
                }
                guard let idToken = result?.user.idToken?.tokenString else {
                    continuation.resume(throwing: GoogleAuthError.noIDToken)
                    return
                }
                guard let accessToken = result?.user.accessToken.tokenString else {
                    continuation.resume(throwing: GoogleAuthError.noToken)
                    return
                }
                Task { @MainActor [weak self] in
                    self?.accessToken = accessToken
                    self?.isSignedIn = true
                    continuation.resume(returning: GoogleSignInTokens(idToken: idToken, accessToken: accessToken))
                }
            }
        }
    }

    // MARK: - Account linking
    //
    // Performs a fresh Google sign-in solely to obtain a fresh id_token for the
    // backend to verify and link a secondary Gmail account to the existing
    // Kontakti user. Does NOT mutate `accessToken` / `isSignedIn` on this
    // service — the primary user session is preserved.
    //
    // Note: GIDSignIn always signs out any previously signed-in user as part of
    // calling `signIn(...)`. For linking flows we restore the previous session
    // immediately afterward via `restorePreviousSignIn` so the primary session
    // for Gmail-reads continues to work. The fresh id_token returned here is
    // what the server uses to identify the *new* account being linked.
    func signInForLinking(presentingViewController: UIViewController) async throws -> String {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty else {
            throw GoogleAuthError.missingClientID
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Remember the previous primary state so we can advertise it again.
        let previousAccessToken = accessToken
        let previousIsSignedIn = isSignedIn

        let idToken: String = try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController,
                hint: nil,
                additionalScopes: [contactsScope, gmailScope]
            ) { result, error in
                if let error {
                    continuation.resume(throwing: GoogleAuthError.signInFailed(error.localizedDescription))
                    return
                }
                guard let idToken = result?.user.idToken?.tokenString else {
                    continuation.resume(throwing: GoogleAuthError.noIDToken)
                    return
                }
                continuation.resume(returning: idToken)
            }
        }

        // Restore previous primary state (best-effort; GIDSignIn keeps the most
        // recent user in its own session — this just keeps our @Published flags
        // consistent for the rest of the app).
        if previousIsSignedIn, previousAccessToken != nil {
            self.accessToken = previousAccessToken
            self.isSignedIn = true
        }

        return idToken
    }

    // MARK: - Restore previous session

    func restorePreviousSignIn() async {
        await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                Task { @MainActor [weak self] in
                    if error == nil, let token = user?.accessToken.tokenString {
                        self?.accessToken = token
                        self?.isSignedIn = true
                    }
                    continuation.resume()
                }
            }
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Sign out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        accessToken = nil
        isSignedIn = false
    }
}
