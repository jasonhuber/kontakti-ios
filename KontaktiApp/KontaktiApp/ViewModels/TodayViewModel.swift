import Foundation
import WidgetKit

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var items: [TodayItem] = []
    @Published var quiz: [ContactPrompt] = []
    @Published var rhythmInsights: [RhythmInsight] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var toast: String?
    /// Counts answered prompts in the current session for the inline toast.
    @Published private(set) var answeredThisSession: Int = 0

    private let api = APIClient.shared

    var count: Int { items.count }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let bundle = try await api.loadTodayWithQuiz(limit: 25)
            items = bundle.items.sorted { $0.priority > $1.priority }
            quiz = bundle.quiz
            rhythmInsights = bundle.rhythmInsights
            answeredThisSession = 0
            writeWidgetSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Full refresh — runs job-change detection + activity refresh, then reloads list.
    func refreshBatch() async {
        isRefreshing = true
        defer { isRefreshing = false }
        // Best-effort sequence; ignore individual failures so the user still gets a fresh list.
        _ = try? await api.detectJobChanges()
        await load()
    }

    func skip(_ item: TodayItem) async {
        // Optimistic remove
        items.removeAll { $0.id == item.id }
        writeWidgetSnapshot()
        // For social-signal / job-change items the key matches an activity id; ack it.
        if item.kind == .socialSignal || item.kind == .jobChange {
            _ = try? await api.acknowledgeActivity(id: item.id)
        }
    }

    func snooze(_ item: TodayItem) async {
        // Optimistic remove. Backend snooze isn't a dedicated endpoint per the contract,
        // so for now we just acknowledge / hide locally.
        items.removeAll { $0.id == item.id }
        writeWidgetSnapshot()
    }

    @discardableResult
    func logReachOut(item: TodayItem, via: String, note: String?) async -> Bool {
        do {
            _ = try await api.logReachOut(itemKey: item.id, via: via, note: note)
            items.removeAll { $0.id == item.id }
            writeWidgetSnapshot()
            toast = "Logged reach-out"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func draft(for item: TodayItem) async -> String {
        if let suggested = item.suggestedMessage, !suggested.isEmpty {
            return suggested
        }
        do {
            return try await api.draftMessage(itemKey: item.id)
        } catch {
            errorMessage = error.localizedDescription
            return ""
        }
    }

    /// Variant that returns either the draft text or a server-supplied error
    /// message (e.g. the do-not-contact 422 response). Used by the draft sheet
    /// to display refusals inline instead of swallowing them as empty text.
    func draftResult(for item: TodayItem) async -> Result<String, Error> {
        if let suggested = item.suggestedMessage, !suggested.isEmpty {
            return .success(suggested)
        }
        do {
            return .success(try await api.draftMessage(itemKey: item.id))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Quiz

    /// Submit an answer; on success removes the prompt from the queue and
    /// nudges the session counter so we can show the "saved N answers" toast.
    @discardableResult
    func answerPrompt(_ prompt: ContactPrompt, answer: String, structured: [String: Any]? = nil, note: String? = nil) async -> Bool {
        do {
            _ = try await api.answerQuiz(promptId: prompt.id, answer: answer, structured: structured, note: note)
            quiz.removeAll { $0.id == prompt.id }
            answeredThisSession += 1
            if quiz.isEmpty && answeredThisSession > 0 {
                toast = "Thanks — saved \(answeredThisSession) answer\(answeredThisSession == 1 ? "" : "s")"
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Skip a single prompt. `permanent: true` tells the backend never to
    /// ask this specific question for this person again.
    func skipPrompt(_ prompt: ContactPrompt, permanent: Bool = false) async {
        // Optimistic remove
        quiz.removeAll { $0.id == prompt.id }
        _ = try? await api.skipQuiz(promptId: prompt.id, permanent: permanent)
    }

    // MARK: - Widget shared snapshot

    /// Writes the top-4 items as JSON to the shared App Group container so
    /// the widget extension can render without network access, then nudges
    /// WidgetKit to reload the timeline.
    func writeWidgetSnapshot() {
        WidgetSnapshotWriter.write(items: items)
    }
}

/// Centralized writer for the App Group snapshot the widget reads. Lives in
/// the main app's process; the widget process reads via `TodayProvider`.
enum WidgetSnapshotWriter {
    static let appGroup = "group.app.kontakti"
    static let snapshotKey = "today_snapshot"
    static let totalCountKey = "today_total_count"
    static let widgetKind = "TodayWidget"

    /// Mirror of the widget-side `TodaySnapshotItem` — kept in this target so
    /// we don't import the widget target's source. Both shapes must stay in
    /// sync; if the field set grows, update both files together.
    struct SnapshotItem: Codable {
        let id: String
        let personName: String
        let kindLabel: String
        let reason: String
        let kindRaw: String
    }

    static func write(items: [TodayItem]) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let top = items.prefix(4).map { item in
            SnapshotItem(
                id: item.id,
                personName: item.person.fullName,
                kindLabel: item.kind.label,
                reason: item.reason,
                kindRaw: item.kind.rawValue
            )
        }
        if let data = try? JSONEncoder().encode(top) {
            defaults.set(data, forKey: snapshotKey)
        }
        defaults.set(items.count, forKey: totalCountKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}

