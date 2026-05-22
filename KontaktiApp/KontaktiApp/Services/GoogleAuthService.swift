import Foundation
import SwiftUI

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

// NOTE: The GoogleSignIn import below requires the GoogleSignIn SPM package to be
// added to the Xcode project. The code is written against the GoogleSignIn 7.x API.
// import GoogleSignIn  ← uncomment after adding the SPM package

enum GoogleAuthError: LocalizedError {
    case missingClientID
    case signInFailed(String)
    case noToken

    var errorDescription: String? {
        switch self {
        case .missingClientID: return "GIDClientID not found in Info.plist."
        case .signInFailed(let msg): return "Google sign-in failed: \(msg)"
        case .noToken: return "Could not retrieve Google access token."
        }
    }
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
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty else {
            throw GoogleAuthError.missingClientID
        }

        // Uncomment the block below once GoogleSignIn SPM package is added:
        /*
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
                guard let token = result?.user.accessToken.tokenString else {
                    continuation.resume(throwing: GoogleAuthError.noToken)
                    return
                }
                self?.accessToken = token
                self?.isSignedIn = true
                continuation.resume(returning: token)
            }
        }
        */

        // Stub: replace with real GIDSignIn call above.
        throw GoogleAuthError.signInFailed("GoogleSignIn SDK not yet linked. Add the SPM package and uncomment the sign-in block.")
    }

    // MARK: - Restore previous session

    func restorePreviousSignIn() async {
        // Uncomment once GoogleSignIn is linked:
        /*
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                if let token = user?.accessToken.tokenString {
                    self?.accessToken = token
                    self?.isSignedIn = true
                }
                continuation.resume()
            }
        }
        */
    }

    // MARK: - Sign out

    func signOut() {
        // GIDSignIn.sharedInstance.signOut()
        accessToken = nil
        isSignedIn = false
    }
}
