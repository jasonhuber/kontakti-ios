import SwiftUI

@MainActor
final class SocialGroupsViewModel: ObservableObject {
    @Published var groups: [SocialGroup] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var syncingId: String?

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            groups = try await api.listSocialGroups()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sync(_ group: SocialGroup) async -> SocialGroupSyncResult? {
        syncingId = group.id
        defer { syncingId = nil }
        do {
            let res = try await api.syncSocialGroup(id: group.id)
            await load()
            return res
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func delete(_ group: SocialGroup) async {
        do {
            try await api.deleteSocialGroup(id: group.id)
            groups.removeAll { $0.id == group.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SocialGroupsListView: View {
    @StateObject private var vm = SocialGroupsViewModel()
    @State private var showWizard = false
    @State private var lastSyncResult: SocialGroupSyncResult?

    var body: some View {
        List {
            if vm.groups.isEmpty && !vm.isLoading {
                Section {
                    Text("No social groups linked yet.")
                        .foregroundColor(.secondary)
                }
            }
            ForEach(vm.groups) { group in
                SocialGroupRow(
                    group: group,
                    isSyncing: vm.syncingId == group.id,
                    onSync: {
                        Task {
                            if let res = await vm.sync(group) {
                                lastSyncResult = res
                            }
                        }
                    },
                    onDelete: { Task { await vm.delete(group) } }
                )
            }

            if let res = lastSyncResult {
                Section {
                    Text("Last sync: +\(res.created) new, \(res.attached) attached. \(res.memberCount) total members.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            if let error = vm.error {
                Section { Text(error).foregroundColor(.red) }
            }
        }
        .navigationTitle("Social groups")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showWizard = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $showWizard) {
            GroupImportWizardView { Task { await vm.load() } }
        }
    }
}

private struct SocialGroupRow: View {
    let group: SocialGroup
    let isSyncing: Bool
    let onSync: () -> Void
    let onDelete: () -> Void

    @State private var showDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: sourceIcon).foregroundColor(.secondary)
                Text(group.name ?? group.externalId)
                    .font(.body)
                Spacer()
                Text("\(group.memberCount)")
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            if let synced = group.lastSyncedAt {
                Text("Last synced \(synced.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            HStack {
                Button(action: onSync) {
                    HStack(spacing: 4) {
                        if isSyncing { ProgressView().scaleEffect(0.7) }
                        Text(isSyncing ? "Syncing…" : "Sync")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isSyncing)

                Spacer()
                Button(role: .destructive) {
                    showDelete = true
                } label: { Text("Delete") }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        .alert("Delete group?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var sourceIcon: String {
        switch group.source.lowercased() {
        case "facebook": return "f.cursive.circle"
        case "whatsapp": return "phone.circle"
        default: return "person.3"
        }
    }
}
