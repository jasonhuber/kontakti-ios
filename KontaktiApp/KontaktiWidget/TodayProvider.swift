import WidgetKit
import Foundation

/// Shared identifiers between the main app and the widget extension.
enum KontaktiWidgetSharedConfig {
    static let appGroup = "group.app.kontakti"
    static let snapshotKey = "today_snapshot"
    static let totalCountKey = "today_total_count"
    static let widgetKind = "TodayWidget"
}

/// Reads the snapshot the main app writes to the shared App Group container,
/// and emits a timeline that refreshes every 15 minutes.
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh policy: pull again every 15 minutes. The main app also forces
        // reloads via WidgetCenter on snapshot writes (foreground / push).
        let nextRefresh = Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    /// Decode the entry from App Group UserDefaults. Falls back to an empty
    /// entry when nothing has been written yet (fresh install, signed-out, etc).
    private func currentEntry() -> TodayEntry {
        guard let defaults = UserDefaults(suiteName: KontaktiWidgetSharedConfig.appGroup) else {
            return .empty
        }
        let total = defaults.integer(forKey: KontaktiWidgetSharedConfig.totalCountKey)
        guard let data = defaults.data(forKey: KontaktiWidgetSharedConfig.snapshotKey),
              let items = try? JSONDecoder().decode([TodaySnapshotItem].self, from: data) else {
            return TodayEntry(date: Date(), totalCount: total, items: [])
        }
        return TodayEntry(date: Date(), totalCount: max(total, items.count), items: items)
    }
}
