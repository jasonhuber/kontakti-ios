import Foundation
import SwiftUI

@MainActor
final class PersonDetailViewModel: ObservableObject {
    @Published var person: Person?
    @Published var timeline: [TimelineEvent] = []
    @Published var discussions: [Discussion] = []
    @Published var tasks: [KontaktiTask] = []
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activity: [SocialActivity] = []
    @Published var isRefreshingActivity = false
    /// Quiz answers the user has previously given about this person.
    @Published var remembrances: [PersonRemembrance] = []

    private let api = APIClient.shared
    private var currentId: String?

    func load(id: String) async {
        currentId = id
        isLoading = true
        errorMessage = nil
        do {
            async let personTask = api.getPerson(id)
            async let timelineTask = api.getTimeline(id)
            async let notesTask = api.listNotesForPerson(id: id)
            async let tasksTask = api.listTasksForPerson(id: id)
            async let activityTask = api.listActivity(personId: id)
            async let remembrancesTask = api.listRemembrances(personId: id)
            person = try await personTask
            timeline = (try? await timelineTask) ?? []
            notes = (try? await notesTask) ?? []
            tasks = (try? await tasksTask) ?? []
            activity = (try? await activityTask) ?? []
            remembrances = (try? await remembrancesTask) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        guard let id = currentId else { return }
        await load(id: id)
    }

    // MARK: - Activity

    func refreshActivity() async {
        guard let id = currentId else { return }
        isRefreshingActivity = true
        defer { isRefreshingActivity = false }
        do {
            activity = try await api.refreshActivity(personId: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acknowledge(activityId: String) async {
        do {
            try await api.acknowledgeActivity(id: activityId)
            activity.removeAll { $0.id == activityId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Edit

    @discardableResult
    func saveEdit(_ patch: PersonPatch) async -> Bool {
        guard let id = currentId else { return false }
        do {
            let updated = try await api.updatePerson(id: id, patch: patch)
            person = updated
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Notes

    func addNote(title: String?, body: String) async {
        guard let id = currentId else { return }
        do {
            let note = try await api.createNote(personId: id, title: title, body: body)
            notes.insert(note, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNote(_ note: Note, title: String?, body: String) async {
        do {
            let updated = try await api.updateNote(id: note.id, title: title, body: body)
            if let idx = notes.firstIndex(where: { $0.id == note.id }) {
                notes[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteNote(_ note: Note) async {
        do {
            try await api.deleteNote(id: note.id)
            notes.removeAll { $0.id == note.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Tasks

    func addTask(title: String, dueAt: Date?, priority: TaskPriority) async {
        guard let id = currentId else { return }
        do {
            let task = try await api.createTask(
                personId: id,
                title: title,
                dueAt: dueAt,
                priority: priority
            )
            tasks.insert(task, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeTask(_ id: String) async {
        do {
            let updated = try await api.completeTask(id)
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Discussions

    func logDiscussion(type: DiscussionType, happenedAt: Date, summary: String?, title: String? = nil) async {
        guard let id = currentId else { return }
        do {
            _ = try await api.createDiscussionForPerson(
                personId: id,
                type: type,
                happenedAt: happenedAt,
                summary: summary,
                title: title
            )
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Follow-up

    func scheduleFollowup(_ date: Date?) async {
        var patch = PersonPatch()
        if let date {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            patch.nextFollowupAt = iso.string(from: date)
        } else {
            patch.nextFollowupAt = ""
        }
        _ = await saveEdit(patch)
    }
}
