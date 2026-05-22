import Foundation
import SwiftUI

@MainActor
final class PersonDetailViewModel: ObservableObject {
    @Published var person: Person?
    @Published var timeline: [TimelineEvent] = []
    @Published var discussions: [Discussion] = []
    @Published var tasks: [KontaktiTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func load(id: String) async {
        isLoading = true
        errorMessage = nil
        do {
            async let personTask = api.getPerson(id)
            async let timelineTask = api.getTimeline(id)
            person = try await personTask
            timeline = (try? await timelineTask) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func completeTask(id: String) async {
        do {
            let updated = try await api.completeTask(id)
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
