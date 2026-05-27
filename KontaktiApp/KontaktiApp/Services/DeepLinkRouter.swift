import Foundation
import Combine

/// Central router for `kontakti://` URLs from the share extension or other sources.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    private init() {}

    @Published var pendingLinkSocial: LinkSocialPayload?

    func handle(_ url: URL) -> Bool {
        if let payload = LinkSocialPayload.fromURL(url) {
            pendingLinkSocial = payload
            return true
        }
        return false
    }

    func clearPendingLinkSocial() {
        pendingLinkSocial = nil
    }
}
