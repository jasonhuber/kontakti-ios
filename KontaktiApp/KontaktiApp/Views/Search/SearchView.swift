import SwiftUI

struct SearchView: View {
    let onSelect: (SearchResult) -> Void

    @StateObject private var vm = SearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    private var groupedResults: [(type: String, results: [SearchResult])] {
        let types = vm.results.map { $0.type }.uniqued()
        return types.map { type in
            (type: type, results: vm.results.filter { $0.type == type })
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search people, companies...", text: $vm.query)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onChange(of: vm.query) {
                            vm.onQueryChange()
                        }
                    if !vm.query.isEmpty {
                        Button {
                            vm.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                ZStack {
                    Color(.systemGroupedBackground).ignoresSafeArea()

                    if vm.isLoading {
                        VStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if vm.query.count < 2 {
                        VStack {
                            Spacer()
                            Text("Type to search...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else if vm.results.isEmpty {
                        VStack {
                            Spacer()
                            Text("No results for \"\(vm.query)\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(groupedResults, id: \.type) { group in
                                Section(header: Text(group.type.capitalized)) {
                                    ForEach(group.results) { result in
                                        Button {
                                            onSelect(result)
                                            dismiss()
                                        } label: {
                                            SearchResultRowView(result: result)
                                        }
                                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}

private struct SearchResultRowView: View {
    let result: SearchResult

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    private var icon: String {
        switch result.type {
        case "person":     return "person"
        case "company":    return "building.2"
        case "discussion": return "bubble.left"
        case "note":       return "note.text"
        case "task":       return "checkmark.circle"
        default:           return "magnifyingglass"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(indigo.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundColor(indigo)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !result.subtitle.isEmpty {
                    let subtitle = result.subtitle
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Array extension for unique values

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
