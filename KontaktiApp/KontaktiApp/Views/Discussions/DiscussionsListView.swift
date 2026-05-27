import SwiftUI

struct DiscussionsListView: View {
    @StateObject private var vm = DiscussionsViewModel()

    private let allTypes: [DiscussionType?] = [nil, .call, .meeting, .email, .message, .event]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            content
        }
        .navigationTitle("Discussions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.showingLogSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .tint(Color(red: 0.31, green: 0.27, blue: 0.90))
            }
        }
        .sheet(isPresented: $vm.showingLogSheet) {
            LogDiscussionView(vm: vm)
        }
        .searchable(text: $vm.searchText, prompt: "Search discussions")
        .onChange(of: vm.searchText) { _ in
            vm.onSearchChange()
        }
        .onChange(of: vm.selectedType) { _ in
            Task { await vm.load() }
        }
        .task {
            await vm.load()
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            typeFilter

            if vm.isLoading && vm.discussions.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if vm.discussions.isEmpty && !vm.isLoading {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "No discussions",
                    subtitle: "Log a call, meeting, or message to get started"
                )
            } else {
                discussionsList
            }
        }
    }

    private var typeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allTypes, id: \.self) { type in
                    TypeFilterPill(
                        label: type.map { "\($0.emoji) \($0.label)" } ?? "All",
                        isSelected: vm.selectedType == type
                    ) {
                        vm.selectedType = type
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var discussionsList: some View {
        List {
            ForEach(vm.discussions) { discussion in
                NavigationLink(value: discussion) {
                    DiscussionRowView(discussion: discussion)
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Discussion.self) { discussion in
            DiscussionDetailView(discussion: discussion)
        }
        .refreshable {
            await vm.load()
        }
    }
}

private struct TypeFilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? indigo : Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
    }
}

private struct DiscussionRowView: View {
    let discussion: Discussion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(discussion.type.emoji)
                    .font(.body)
                Text(discussion.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Text(discussion.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let summary = discussion.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let participants = discussion.participants, !participants.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(participants.count) participant\(participants.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
