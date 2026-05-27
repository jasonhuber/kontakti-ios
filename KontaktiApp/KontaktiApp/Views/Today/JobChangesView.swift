import SwiftUI

@MainActor
final class JobChangesViewModel: ObservableObject {
    @Published var changes: [TodayItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIClient.shared

    func runDetection() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await api.detectJobChanges()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func load() async {
        do {
            let all = try await api.listToday(limit: 50)
            changes = all.filter { $0.kind == .jobChange }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct JobChangesView: View {
    @StateObject private var vm = JobChangesViewModel()
    @State private var drafting: TodayItem?
    @StateObject private var todayVM = TodayViewModel()

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        List {
            Section {
                Button {
                    Task { await vm.runDetection() }
                } label: {
                    HStack {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(vm.isLoading ? "Detecting…" : "Run detection")
                    }
                }
                .disabled(vm.isLoading)
            }

            if vm.changes.isEmpty && !vm.isLoading {
                Section {
                    Text("No detected job changes.")
                        .foregroundColor(.secondary)
                }
            } else {
                Section("Recent job changes") {
                    ForEach(vm.changes) { change in
                        HStack(alignment: .top, spacing: 12) {
                            AvatarView(name: change.person.fullName, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(change.person.fullName).font(.body)
                                Text(change.reason)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Congratulate") {
                                drafting = change
                            }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(indigo)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Job changes")
        .task { await vm.load() }
        .sheet(item: $drafting) { item in
            DraftMessageSheet(item: item, vm: todayVM)
        }
    }
}
