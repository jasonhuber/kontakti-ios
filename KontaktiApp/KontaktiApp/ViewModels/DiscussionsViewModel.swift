import Foundation
import SwiftUI
import Combine

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
    private let store = OfflineStore.shared
    private let networkMonitor = NetworkMonitor.shared
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .kontaktiDidBecomeActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in Task { [weak self] in await self?.load(reset: true) } }
            .store(in: &cancellables)
    }

    func load(reset: Bool = false) async {
        if reset {
            discussions = []
            currentPage = 1
            hasMore = true
        }

        if discussions.isEmpty {
            let cached = store.fetchDiscussions()
            if !cached.isEmpty {
                discussions = cached.map { entity in
                    Discussion(
                        id: entity.id,
                        title: entity.title,
                        date: entity.date,
                        type: entity.displayType,
                        summary: entity.summary,
                        body: nil,
                        participants: nil,
                        createdAt: entity.updatedAt,
                        updatedAt: entity.updatedAt
                    )
                }
            }
        }

        guard networkMonitor.isConnected else { return }
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
            if reset || currentPage == 2 {
                store.upsertDiscussions(result.data)
            }
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
        if networkMonitor.isConnected {
            let discussion = try await api.createDiscussion(req)
            store.upsertDiscussions([discussion])
        } else {
            await SyncQueue.shared.enqueue(.logDiscussion(req))
        }
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
