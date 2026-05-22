import Foundation
import SwiftUI

@MainActor
final class DiscussionsViewModel: ObservableObject {
    @Published var discussions: [Discussion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedType: DiscussionType? = nil
    @Published var showingLogSheet = false
    @Published var currentPage = 1
    @Published var hasMore = true

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?

    func load(reset: Bool = false) async {
        if reset {
            discussions = []
            currentPage = 1
            hasMore = true
        }
        guard hasMore && !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.listDiscussions(
                query: searchText.isEmpty ? nil : searchText,
                type: selectedType?.rawValue,
                page: currentPage
            )
            if reset {
                discussions = result.data
            } else {
                discussions.append(contentsOf: result.data)
            }
            hasMore = currentPage < result.lastPage
            if hasMore { currentPage += 1 }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createDiscussion(
        title: String,
        date: Date,
        type: DiscussionType,
        summary: String?,
        participantIds: [String]
    ) async throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let req = CreateDiscussionRequest(
            title: title,
            date: formatter.string(from: date),
            type: type.rawValue,
            summary: summary?.isEmpty == true ? nil : summary,
            participantIds: participantIds.isEmpty ? nil : participantIds
        )
        _ = try await api.createDiscussion(req)
        await load(reset: true)
    }

    func onSearchChange() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await load(reset: true)
        }
    }

    func onTypeChange() async {
        await load(reset: true)
    }
}
