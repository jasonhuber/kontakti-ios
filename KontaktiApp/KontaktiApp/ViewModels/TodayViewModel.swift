import Foundation
import WidgetKit

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var items: [TodayItem] = []
    @Published var quiz: [ContactPrompt] = []
    @Published var rhythmInsights: [RhythmInsight] = []
    @Published var suggestions: [ReachOutSuggestion] = []
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
            async let bundleTask = api.loadTodayWithQuiz(limit: 25)
            async let suggestionsTask = api.loadSuggestions(limit: 6)
            let bundle = try await bundleTask
            let suggestionsResponse = (try? await suggestionsTask) ?? ReachOutSuggestionsResponse(count: 0, suggestions: [])
            items = bundle.items.sorted { $0.priority > $1.priority }
            quiz = bundle.quiz
            rhythmInsights = bundle.rhythmInsights
            suggestions = suggestionsResponse.suggestions
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
        // Optimistic remove first so the UI responds instantly.
        items.removeAll { $0.id == item.id }
        writeWidgetSnapshot()
        if item.kind == .socialSignal || item.kind == .jobChange {
            _ = try? await api.acknowledgeActivity(id: item.id)
        } else {
            // All other kinds (cadence, follow-up, birthday, etc.) go through
            // the standard skip endpoint so the server marks them done.
            _ = try? await api.skipTodayItem(itemKey: item.id)
        }
    }

    func snooze(_ item: TodayItem) async {
        // Optimistic remove first so the UI responds instantly.
        items.removeAll { $0.id == item.id }
        writeWidgetSnapshot()
        _ = try? await api.snoozeTodayItem(itemKey: item.id)
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

    // MARK: - Suggestions

    func completeSuggestion(_ suggestion: ReachOutSuggestion) async {
        suggestions.removeAll { $0.scheduleId == suggestion.scheduleId }
        _ = try? await api.completeSuggestion(scheduleId: suggestion.scheduleId)
    }

    func snoozeSuggestion(_ suggestion: ReachOutSuggestion) async {
        suggestions.removeAll { $0.scheduleId == suggestion.scheduleId }
        _ = try? await api.snoozeSuggestion(scheduleId: suggestion.scheduleId, days: 30)
    }

    /// Record how the user reached out to a suggested person (channel + optional
    /// note). The /log-contact endpoint also marks the schedule item done server-
    /// side, so on success we just drop it from the list.
    @discardableResult
    func logReachOut(suggestion: ReachOutSuggestion, via: String, note: String?) async -> Bool {
        do {
            _ = try await api.logContactDirect(personId: suggestion.personId, via: via, note: note)
            suggestions.removeAll { $0.scheduleId == suggestion.scheduleId }
            toast = "Logged reach-out to \(suggestion.personFirstName ?? suggestion.name)"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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

