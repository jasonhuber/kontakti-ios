import WidgetKit
import Foundation

/// Snapshot of a Today inbox item that the widget renders. Decoded from
/// the JSON written by the main app into the shared App Group UserDefaults.
struct TodaySnapshotItem: Codable, Hashable, Identifiable {
    let id: String
    let personName: String
    let kindLabel: String
    let reason: String
    let kindRaw: String

    /// SF Symbol name appropriate for this item kind.
    var iconName: String {
        switch kindRaw {
        case "birthday": return "birthday.cake.fill"
        case "cadence_overdue": return "clock.badge.exclamationmark"
        case "follow_up_due": return "calendar.badge.clock"
        case "job_change": return "briefcase"
        case "social_signal": return "sparkles"
        case "anniversary_met": return "star"
        default: return "bell"
        }
    }
}

/// A single timeline entry — what the widget displays at a given moment.
struct TodayEntry: TimelineEntry {
    let date: Date
    let totalCount: Int
    let items: [TodaySnapshotItem]

    static let placeholder = TodayEntry(
        date: Date(),
        totalCount: 3,
        items: [
            TodaySnapshotItem(id: "1", personName: "Alex Rivera", kindLabel: "Birthday", reason: "Turns 32 today", kindRaw: "birthday"),
            TodaySnapshotItem(id: "2", personName: "Sam Chen", kindLabel: "Overdue", reason: "Haven't spoken in 90 days", kindRaw: "cadence_overdue"),
            TodaySnapshotItem(id: "3", personName: "Jordan Patel", kindLabel: "Job change", reason: "New role at Stripe", kindRaw: "job_change"),
            TodaySnapshotItem(id: "4", personName: "Casey Wong", kindLabel: "Follow-up", reason: "Coffee scheduled", kindRaw: "follow_up_due")
        ]
    )

    static let empty = TodayEntry(date: Date(), totalCount: 0, items: [])
}
