import Foundation
import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?

    func onQueryChange() {
        guard query.count >= 2 else {
            results = []
            errorMessage = nil
            return
        }
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            isLoading = true
            errorMessage = nil
            do {
                let response = try await api.search(query: query)
                results = response.results
            } catch {
                errorMessage = error.localizedDescription
                results = []
            }
            isLoading = false
        }
    }

    func clear() {
        query = ""
        results = []
        errorMessage = nil
        searchTask?.cancel()
    }
}
