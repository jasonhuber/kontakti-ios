import Foundation
import SwiftUI
import Combine

@MainActor
final class PeopleViewModel: ObservableObject {
    @Published var people: [Person] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedStrength: RelationshipStrength? = nil
    @Published var currentPage = 1
    @Published var hasMore = true

    // MARK: - Import sheet state

    @Published var showingImportSheet = false
    @Published var showLinkedInImport = false
    @Published var importSource: ImportSource = .device
    @Published var importCandidates: [ImportCandidate] = []
    @Published var importError: String?
    @Published var isLoadingImport = false

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
            people = []
            currentPage = 1
            hasMore = true
        }

        // Immediately serve cached records before hitting the network
        if people.isEmpty {
            let cached = store.fetchPeople()
            if !cached.isEmpty {
                people = cached.map { entity in
                    // Map PersonEntity -> Person for display
                    // This is a lightweight mapping; only list-display fields are available
                    Person(
                        id: entity.id,
                        firstName: entity.firstName,
                        lastName: entity.lastName,
                        fullName: entity.fullName,
                        email: entity.email,
                        phone: entity.phone,
                        linkedinUrl: nil,
                        avatarUrl: entity.avatarUrl,
                        companyId: entity.companyId,
                        company: nil,
                        title: entity.title,
                        relationshipStrength: entity.displayStrength,
                        lastContactedAt: entity.lastContactedAt,
                        nextFollowupAt: nil,
                        notes: nil,
                        tags: [],
                        discussionsCount: nil,
                        dealsCount: nil,
                        tasksCount: nil,
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
            let result = try await api.listPeople(
                query: searchText.isEmpty ? nil : searchText,
                page: currentPage
            )
            if reset {
                people = result.data
            } else {
                people.append(contentsOf: result.data)
            }
            hasMore = currentPage < result.lastPage
            if hasMore { currentPage += 1 }

            // Update local cache (only on the first page / reset to avoid partial writes).
            // On a reset we clear first so server-side deletes (e.g. a contact wipe)
            // are reflected in the cache rather than leaving stale records behind.
            if reset || currentPage == 2 {
                if reset {
                    store.clearAll()
                }
                store.upsertPeople(result.data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadNextPageIfNeeded(currentItem: Person) async {
        guard let last = people.last, last.id == currentItem.id else { return }
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

    // MARK: - Device contacts import

    func startDeviceImport() {
        importSource = .device
        importError = nil
        isLoadingImport = true

        Task {
            do {
                let candidates = try await ContactsImporter.shared.fetchNewCandidates()
                importCandidates = candidates
                importError = nil
                showingImportSheet = true
            } catch {
                importError = error.localizedDescription
            }
            isLoadingImport = false
        }
    }

    // MARK: - Gmail import

    func startGmailImport(accessToken: String) {
        importSource = .gmail
        importError = nil
        isLoadingImport = true

        Task {
            do {
                let candidates = try await GmailContactsService.shared.fetchNewCandidates(accessToken: accessToken)
                importCandidates = candidates
                importError = nil
                showingImportSheet = true
            } catch {
                importError = error.localizedDescription
            }
            isLoadingImport = false
        }
    }
}
