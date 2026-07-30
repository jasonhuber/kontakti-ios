import SwiftUI

/// Relationship-fitness dashboard. Named `ProgressDashboardView` to avoid
/// colliding with SwiftUI's built-in `ProgressView`.
struct ProgressDashboardView: View {
    @StateObject private var vm = ProgressDashboardViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if vm.isLoading && vm.dashboard == nil {
                ProgressView()
            } else if let d = vm.dashboard {
                ScrollView {
                    VStack(spacing: 14) {
                        EncouragementBanner(encouragement: d.encouragement)
                        FitnessHeroCard(dashboard: d)
                        HStack(spacing: 14) {
                            GoalCard(goal: d.goal)
                            StreakCard(streak: d.streak)
                        }
                        HStack(spacing: 14) {
                            MiniScoreCard(
                                icon: "person.line.dotted.person.fill",
                                title: "Keeping in touch",
                                score: d.inTouch.score,
                                detail: d.inTouch.tracked == 0
                                    ? "Set a cadence to start"
                                    : "\(d.inTouch.onCadence)/\(d.inTouch.tracked) on cadence · \(d.inTouch.overdue) overdue"
                            )
                            MiniScoreCard(
                                icon: "sparkles",
                                title: "Curating",
                                score: d.curation.score,
                                detail: d.curation.total == 0
                                    ? "No contacts yet"
                                    : "\(d.curation.complete)/\(d.curation.total) clean · \(d.curation.needsAttention) to fix"
                            )
                        }
                        AchievementsCard(achievements: d.achievements)
                    }
                    .padding(16)
                }
                .refreshable { await vm.load() }
            } else if let error = vm.errorMessage {
                EmptyStateView(icon: "chart.line.uptrend.xyaxis",
                               title: "Couldn't load progress",
                               subtitle: error)
            } else {
                EmptyStateView(icon: "chart.line.uptrend.xyaxis",
                               title: "No progress yet",
                               subtitle: "Log a few outreaches and your score comes alive.")
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
    }
}

// MARK: - Shared helpers

private let kIndigo = Color(red: 0.31, green: 0.27, blue: 0.90)

private func scoreColor(_ score: Int?) -> Color {
    guard let s = score else { return Color(.systemGray3) }
    if s >= 80 { return .green }
    if s >= 55 { return .orange }
    return .red
}

private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
}

// MARK: - Encouragement banner

private struct EncouragementBanner: View {
    let encouragement: Encouragement

    private var color: Color {
        switch encouragement.tone {
        case "celebrate": return .green
        case "nudge":     return .orange
        case "urgent":    return .red
        case "setup":     return kIndigo
        default:          return .secondary
        }
    }
    private var symbol: String {
        switch encouragement.tone {
        case "celebrate": return "trophy.fill"
        case "nudge":     return "target"
        case "urgent":    return "flame.fill"
        case "setup":     return "sparkles"
        default:          return "hand.thumbsup.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundColor(color)
                .font(.headline)
            Text(encouragement.message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Fitness hero (ring + level)

private struct FitnessHeroCard: View {
    let dashboard: GamificationDashboard

    var body: some View {
        card {
            VStack(spacing: 18) {
                FitnessRing(score: dashboard.fitnessScore)

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill").foregroundColor(kIndigo).font(.footnote)
                        Text("Level \(dashboard.level.level) · \(dashboard.level.title)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    ProgressBar(value: Double(dashboard.level.xpIntoLevel),
                                total: Double(max(dashboard.level.xpForNext, 1)),
                                color: kIndigo)
                    HStack {
                        Text("\(dashboard.level.xp) XP")
                        Spacer()
                        Text("\(dashboard.level.xpIntoLevel)/\(dashboard.level.xpForNext) to level \(dashboard.level.level + 1)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    StatTile(value: dashboard.totals.outreachLifetime, label: "TOUCHES")
                    StatTile(value: dashboard.totals.reviewed, label: "CURATED")
                    StatTile(value: dashboard.totals.people, label: "PEOPLE")
                }
            }
        }
    }
}

private struct FitnessRing: View {
    let score: Int?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, score ?? 0))) / 100)
                .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(score.map(String.init) ?? "—")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Fitness").font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(width: 150, height: 150)
    }
}

// MARK: - Goal + streak

private struct GoalCard: View {
    let goal: GoalInfo
    private var done: Bool { goal.remaining == 0 }

    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Label("This week's goal", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(done ? .green : kIndigo)
                Text(goal.title).font(.footnote).foregroundColor(.primary)
                ProgressBar(value: Double(goal.progress),
                            total: Double(max(goal.target, 1)),
                            color: done ? .green : kIndigo)
                Text(done ? "Done — \(goal.progress) reached. Nice."
                          : "\(goal.progress)/\(goal.target) reached · \(goal.remaining) to go")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

private struct StreakCard: View {
    let streak: StreakMetrics

    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(streak.atRisk ? .red : (streak.currentWeeks > 0 ? .orange : Color(.systemGray3)))
                    Text("Weekly streak").font(.subheadline.weight(.semibold))
                    Spacer()
                    if streak.atRisk {
                        Text("at risk")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streak.currentWeeks)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(streak.currentWeeks == 1 ? "week" : "weeks")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Text("Longest: \(streak.longestWeeks) · \(streak.thisWeekOutreach) this week")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Mini score

private struct MiniScoreCard: View {
    let icon: String
    let title: String
    let score: Int?
    let detail: String

    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundColor(.secondary).font(.footnote)
                    Text(title).font(.footnote.weight(.medium))
                    Spacer()
                    Text(score.map { "\($0)%" } ?? "—")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(scoreColor(score))
                }
                ProgressBar(value: Double(score ?? 0), total: 100, color: scoreColor(score))
                Text(detail).font(.caption2).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Achievements

private struct AchievementsCard: View {
    let achievements: [Achievement]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var earnedCount: Int { achievements.filter { $0.earned }.count }

    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill").foregroundColor(.orange).font(.footnote)
                    Text("Achievements").font(.subheadline.weight(.semibold))
                    Text("\(earnedCount)/\(achievements.count)")
                        .font(.caption).foregroundColor(.secondary)
                }
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(achievements) { AchievementBadge(achievement: $0) }
                }
            }
        }
    }
}

private struct AchievementBadge: View {
    let achievement: Achievement

    private func symbol(_ name: String) -> String {
        switch name {
        case "Handshake":   return "hand.wave.fill"
        case "Flame":       return "flame.fill"
        case "Trophy":      return "trophy.fill"
        case "Sparkles":    return "sparkles"
        case "Users":       return "person.3.fill"
        case "CheckCircle2": return "checkmark.seal.fill"
        case "HeartPulse":  return "heart.fill"
        case "Send":        return "paperplane.fill"
        default:            return "star.fill"
        }
    }

    private var pct: Int {
        guard achievement.progress.target > 0 else { return 0 }
        return min(100, Int(round(100.0 * Double(achievement.progress.current) / Double(achievement.progress.target))))
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(achievement.earned ? Color.orange.opacity(0.18) : Color(.systemGray5))
                    .frame(width: 40, height: 40)
                Image(systemName: achievement.earned ? symbol(achievement.icon) : "lock.fill")
                    .foregroundColor(achievement.earned ? .orange : Color(.systemGray))
            }
            Text(achievement.title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(achievement.earned ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if !achievement.earned {
                Text("\(achievement.progress.current)/\(achievement.progress.target)")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(achievement.earned ? Color.orange.opacity(0.08) : Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Small reusable bits

private struct ProgressBar: View {
    let value: Double
    let total: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule().fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, total > 0 ? value / total : 0))))
            }
        }
        .frame(height: 8)
    }
}

private struct StatTile: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    NavigationStack { ProgressDashboardView() }
}
