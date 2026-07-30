import Foundation

// MARK: - Gamification (relationship fitness)
// Mirrors the backend GamificationService payload (GET /gamification/dashboard).
// Explicit CodingKeys throughout — the shared decoder does NOT use
// .convertFromSnakeCase.

struct GamificationDashboard: Decodable {
    let fitnessScore: Int?
    let inTouch: InTouchMetrics
    let curation: CurationMetrics
    let streak: StreakMetrics
    let level: LevelInfo
    let goal: GoalInfo
    let totals: TotalsInfo
    let achievements: [Achievement]
    let encouragement: Encouragement

    enum CodingKeys: String, CodingKey {
        case fitnessScore = "fitness_score"
        case inTouch = "in_touch"
        case curation, streak, level, goal, totals, achievements, encouragement
    }
}

struct InTouchMetrics: Decodable {
    let score: Int?
    let tracked: Int
    let onCadence: Int
    let overdue: Int
    let neverContacted: Int

    enum CodingKeys: String, CodingKey {
        case score, tracked, overdue
        case onCadence = "on_cadence"
        case neverContacted = "never_contacted"
    }
}

struct CurationMetrics: Decodable {
    let score: Int?
    let total: Int
    let complete: Int
    let needsAttention: Int

    enum CodingKeys: String, CodingKey {
        case score, total, complete
        case needsAttention = "needs_attention"
    }
}

struct StreakMetrics: Decodable {
    let currentWeeks: Int
    let longestWeeks: Int
    let atRisk: Bool
    let thisWeekOutreach: Int
    let thisWeekActiveDays: Int

    enum CodingKeys: String, CodingKey {
        case currentWeeks = "current_weeks"
        case longestWeeks = "longest_weeks"
        case atRisk = "at_risk"
        case thisWeekOutreach = "this_week_outreach"
        case thisWeekActiveDays = "this_week_active_days"
    }
}

struct LevelInfo: Decodable {
    let level: Int
    let title: String
    let xp: Int
    let xpIntoLevel: Int
    let xpForNext: Int

    enum CodingKeys: String, CodingKey {
        case level, title, xp
        case xpIntoLevel = "xp_into_level"
        case xpForNext = "xp_for_next"
    }
}

struct GoalInfo: Decodable {
    let title: String
    let target: Int
    let progress: Int
    let remaining: Int
    let period: String
}

struct TotalsInfo: Decodable {
    let people: Int
    let outreachLifetime: Int
    let reviewed: Int
    let tasksCompleted: Int

    enum CodingKeys: String, CodingKey {
        case people, reviewed
        case outreachLifetime = "outreach_lifetime"
        case tasksCompleted = "tasks_completed"
    }
}

struct Achievement: Decodable, Identifiable {
    let key: String
    let title: String
    let description: String
    let icon: String
    let earned: Bool
    let progress: AchievementProgress

    var id: String { key }
}

struct AchievementProgress: Decodable {
    let current: Int
    let target: Int
}

struct Encouragement: Decodable {
    let message: String
    let tone: String   // celebrate | nudge | urgent | setup | steady
}
