import SwiftUI

struct FeedView: View {
    @StateObject private var vm = FeedViewModel()

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if vm.isLoading && vm.items.isEmpty {
                ProgressView()
            } else if vm.items.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "No activity yet",
                    subtitle: "Your recent CRM activity will appear here"
                )
            } else {
                List {
                    ForEach(vm.items) { item in
                        FeedItemRowView(item: item)
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await vm.load()
                }
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await vm.load()
        }
    }
}

private struct FeedItemRowView: View {
    let item: FeedItem

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    private var icon: String {
        switch item.entityType {
        case "person":     return "person"
        case "company":    return "building.2"
        case "discussion": return "bubble.left"
        case "note":       return "note.text"
        case "task":       return "checkmark.circle"
        default:           return "circle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(indigo.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.verbLabel)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(relativeDate(item.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func relativeDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let components = calendar.dateComponents([.hour, .minute], from: date, to: now)
            let hours = components.hour ?? 0
            let minutes = components.minute ?? 0
            if hours == 0 {
                return minutes <= 1 ? "Just now" : "\(minutes)m ago"
            }
            return "\(hours)h ago"
        }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let components = calendar.dateComponents([.day], from: date, to: now)
        let days = abs(components.day ?? 0)
        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
