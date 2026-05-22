import Foundation
import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var items: [FeedItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await api.getFeed()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await load()
    }
}
