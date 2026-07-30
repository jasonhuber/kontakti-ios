import Foundation
import SwiftUI
import Combine

@MainActor
final class ProgressDashboardViewModel: ObservableObject {
    @Published var dashboard: GamificationDashboard?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .kontaktiDidBecomeActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in Task { [weak self] in await self?.load() } }
            .store(in: &cancellables)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            dashboard = try await api.getGamificationDashboard()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await load()
    }
}
