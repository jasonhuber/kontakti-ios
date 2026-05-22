import Foundation
import SwiftUI
import Combine

@MainActor
final class CompaniesViewModel: ObservableObject {
    @Published var companies: [Company] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var currentPage = 1
    @Published var hasMore = true

    private let api = APIClient.shared
    private let store = OfflineStore.shared
    private let networkMonitor = NetworkMonitor.shared
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Flush the sync queue whenever connectivity is restored
        networkMonitor.$isConnected
            .removeDuplicates()
            .filter { $0 }
            .sink { _ in
                Task { await SyncQueue.shared.flush() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load

    func load(reset: Bool = false) async {
        if reset {
            companies = []
            currentPage = 1
            hasMore = true
        }

        // Immediately serve cached records before hitting the network
        if companies.isEmpty {
            let cached = store.fetchCompanies()
            if !cached.isEmpty {
                companies = cached.map { entity in
                    Company(
                        id: entity.id,
                        name: entity.name,
                        domain: entity.domain,
                        logoUrl: entity.logoUrl,
                        industry: entity.industry,
                        sizeRange: entity.sizeRange,
                        linkedinUrl: nil,
                        website: nil,
                        notes: nil,
                        tags: [],
                        peopleCount: entity.peopleCount,
                        dealsCount: nil,
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
            let result = try await api.listCompanies(
                query: searchText.isEmpty ? nil : searchText,
                page: currentPage
            )
            if reset {
                companies = result.data
            } else {
                companies.append(contentsOf: result.data)
            }
            hasMore = currentPage < result.lastPage
            if hasMore { currentPage += 1 }

            // Update local cache on first page load
            if reset || currentPage == 2 {
                store.upsertCompanies(result.data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadNextPageIfNeeded(currentItem: Company) async {
        guard let last = companies.last, last.id == currentItem.id else { return }
        await load()
    }

    func onSearchChange() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await load(reset: true)
        }
    }
}
