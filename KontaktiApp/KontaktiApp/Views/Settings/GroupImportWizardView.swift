import SwiftUI

/// Tabbed picker wizard for importing real social groups (Facebook + WhatsApp).
///
/// State machine per tab:
///   Facebook:
///     .loading -> listFacebookGroups()
///       -> .success(groups) -> picker UI -> import flow
///       -> .failure(ProviderError) -> remediation card with Retry
///   WhatsApp:
///     .loadingStatus -> whatsappStatus()
///       paired:false -> .pairing (renders QRPairingView, polls until paired)
///       paired:true  -> .loadingGroups -> listWhatsappGroups()
///         -> .success(groups) / .failure(ProviderError)
///
/// Import: per selected group, sequentially POST /social-groups then
/// POST /social-groups/{id}/sync. Per-group errors do not block siblings.
struct GroupImportWizardView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case facebook, whatsapp
        var id: String { rawValue }
        var label: String {
            switch self {
            case .facebook: return "Facebook"
            case .whatsapp: return "WhatsApp"
            }
        }
    }

    var onCompleted: () -> Void = {}

    @State private var tab: Tab = .facebook
    @State private var toast: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Source", selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    switch tab {
                    case .facebook:
                        FacebookPickerSection(onImported: handleImported)
                    case .whatsapp:
                        WhatsAppPickerSection(onImported: handleImported)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Import group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
        }
    }

    private func handleImported(groupCount: Int, memberCount: Int) {
        toast = "Imported \(memberCount) contacts from \(groupCount) groups"
        onCompleted()
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        }
    }
}

// MARK: - Facebook section

private struct FacebookPickerSection: View {
    var onImported: (_ groupCount: Int, _ memberCount: Int) -> Void

    enum LoadState {
        case loading
        case success([FacebookGroup])
        case failure(ProviderError)
        case error(String)
    }

    @State private var state: LoadState = .loading
    @State private var selected: Set<String> = []
    @State private var progress: ImportProgressState?

    private let api = APIClient.shared

    var body: some View {
        ZStack {
            switch state {
            case .loading:
                ProgressView("Loading your Facebook groups…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let groups):
                pickerList(groups)
            case .failure(let err):
                ProviderRemediationCard(
                    icon: "f.cursive.circle",
                    iconColor: Color(red: 0.23, green: 0.35, blue: 0.60),
                    title: "Facebook isn't connected",
                    message: err.remediation ?? "Reconnect Facebook to see your groups.",
                    onRetry: { Task { await load() } }
                )
            case .error(let msg):
                ProviderRemediationCard(
                    icon: "exclamationmark.triangle",
                    iconColor: .orange,
                    title: "Couldn't load groups",
                    message: msg,
                    onRetry: { Task { await load() } }
                )
            }

            if let progress {
                ImportProgressOverlay(state: progress)
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func pickerList(_ groups: [FacebookGroup]) -> some View {
        if groups.isEmpty {
            ContentUnavailableView(
                "No groups found",
                systemImage: "person.3",
                description: Text("Facebook didn't return any groups for your account.")
            )
        } else {
            VStack(spacing: 0) {
                List(groups) { g in
                    GroupPickRow(
                        name: g.name,
                        memberCount: g.memberCount,
                        avatarUrl: g.avatarUrl,
                        isSelected: selected.contains(g.id),
                        onToggle: { toggle(g.id) }
                    )
                }
                .listStyle(.plain)

                importToolbar(
                    count: selected.count,
                    enabled: !selected.isEmpty && progress == nil,
                    action: { Task { await importSelected(from: groups) } }
                )
            }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func load() async {
        state = .loading
        do {
            let res = try await api.listFacebookGroups()
            switch res {
            case .success(let groups): state = .success(groups)
            case .failure(let err):    state = .failure(err)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func importSelected(from groups: [FacebookGroup]) async {
        let picked = groups.filter { selected.contains($0.id) }
        await runImport(
            picked.map {
                ImportTarget(source: "facebook_group", externalId: $0.id, name: $0.name)
            },
            progressBinding: $progress,
            api: api,
            onImported: onImported
        )
    }
}

// MARK: - WhatsApp section

private struct WhatsAppPickerSection: View {
    var onImported: (_ groupCount: Int, _ memberCount: Int) -> Void

    enum LoadState {
        case loadingStatus
        case pairing
        case loadingGroups
        case success([WhatsappGroup])
        case failure(ProviderError)
        case error(String)
    }

    @State private var state: LoadState = .loadingStatus
    @State private var selected: Set<String> = []
    @State private var progress: ImportProgressState?

    private let api = APIClient.shared

    var body: some View {
        ZStack {
            switch state {
            case .loadingStatus:
                ProgressView("Checking WhatsApp link…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .pairing:
                QRPairingView(
                    title: "Link WhatsApp",
                    instructions: [
                        "Open WhatsApp on your phone.",
                        "Tap Settings, then Linked Devices.",
                        "Tap Link a Device and scan this code."
                    ],
                    fetchQR: { try await api.whatsappQR() },
                    fetchStatus: { try await api.whatsappStatus() },
                    onPaired: {
                        withAnimation { state = .loadingGroups }
                        Task { await loadGroups() }
                    }
                )
                .transition(.opacity)
            case .loadingGroups:
                ProgressView("Loading your WhatsApp groups…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .success(let groups):
                pickerList(groups)
            case .failure(let err):
                ProviderRemediationCard(
                    icon: "phone.circle",
                    iconColor: .green,
                    title: "WhatsApp isn't ready",
                    message: err.remediation ?? "Re-link your phone to load groups.",
                    onRetry: { Task { await loadInitial() } }
                )
            case .error(let msg):
                ProviderRemediationCard(
                    icon: "exclamationmark.triangle",
                    iconColor: .orange,
                    title: "Couldn't load WhatsApp",
                    message: msg,
                    onRetry: { Task { await loadInitial() } }
                )
            }

            if let progress {
                ImportProgressOverlay(state: progress)
            }
        }
        .task { await loadInitial() }
    }

    @ViewBuilder
    private func pickerList(_ groups: [WhatsappGroup]) -> some View {
        if groups.isEmpty {
            ContentUnavailableView(
                "No groups found",
                systemImage: "person.3",
                description: Text("You're not a member of any WhatsApp groups yet.")
            )
        } else {
            VStack(spacing: 0) {
                List(groups) { g in
                    GroupPickRow(
                        name: g.name,
                        memberCount: g.memberCount,
                        avatarUrl: g.avatarUrl,
                        isSelected: selected.contains(g.id),
                        isAdmin: g.isAdmin,
                        onToggle: { toggle(g.id) }
                    )
                }
                .listStyle(.plain)

                importToolbar(
                    count: selected.count,
                    enabled: !selected.isEmpty && progress == nil,
                    action: { Task { await importSelected(from: groups) } }
                )
            }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func loadInitial() async {
        state = .loadingStatus
        do {
            let status = try await api.whatsappStatus()
            if status.paired {
                state = .loadingGroups
                await loadGroups()
            } else {
                state = .pairing
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func loadGroups() async {
        do {
            let res = try await api.listWhatsappGroups()
            switch res {
            case .success(let groups): state = .success(groups)
            case .failure(let err):    state = .failure(err)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func importSelected(from groups: [WhatsappGroup]) async {
        let picked = groups.filter { selected.contains($0.id) }
        await runImport(
            picked.map {
                ImportTarget(source: "whatsapp_group", externalId: $0.jid, name: $0.name)
            },
            progressBinding: $progress,
            api: api,
            onImported: onImported
        )
    }
}

// MARK: - Shared bottom import button

@ViewBuilder
private func importToolbar(count: Int, enabled: Bool, action: @escaping () -> Void) -> some View {
    let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    VStack(spacing: 0) {
        Divider()
        Button(action: action) {
            Text(count == 0 ? "Select groups to import" : "Import (\(count)) selected")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(indigo)
        .disabled(!enabled)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

// MARK: - Import pipeline

private struct ImportTarget {
    let source: String
    let externalId: String
    let name: String?
}

private struct ImportProgressState {
    var currentName: String
    var currentMemberCount: Int?
    var completed: Int
    var total: Int
    var perGroupErrors: [String]
}

private func runImport(
    _ targets: [ImportTarget],
    progressBinding: Binding<ImportProgressState?>,
    api: APIClient,
    onImported: @escaping (_ groupCount: Int, _ memberCount: Int) -> Void
) async {
    guard !targets.isEmpty else { return }
    progressBinding.wrappedValue = ImportProgressState(
        currentName: targets[0].name ?? targets[0].externalId,
        currentMemberCount: nil,
        completed: 0,
        total: targets.count,
        perGroupErrors: []
    )

    var totalMembers = 0
    var successfulGroups = 0

    for (idx, target) in targets.enumerated() {
        progressBinding.wrappedValue?.currentName = target.name ?? target.externalId
        progressBinding.wrappedValue?.currentMemberCount = nil

        do {
            let group = try await api.createSocialGroup(
                source: target.source,
                externalId: target.externalId,
                name: target.name
            )
            let result = try await api.syncSocialGroup(id: group.id)
            totalMembers += result.memberCount
            successfulGroups += 1
            progressBinding.wrappedValue?.currentMemberCount = result.memberCount
        } catch {
            progressBinding.wrappedValue?.perGroupErrors.append(
                "\(target.name ?? target.externalId): \(error.localizedDescription)"
            )
        }

        progressBinding.wrappedValue?.completed = idx + 1
    }

    // Hold the final state briefly so user sees completion.
    try? await Task.sleep(nanoseconds: 400_000_000)
    progressBinding.wrappedValue = nil
    onImported(successfulGroups, totalMembers)
}

private struct ImportProgressOverlay: View {
    let state: ImportProgressState

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ProgressView()
                    Text("Importing \(state.currentName)…")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer()
                    Text("\(state.completed)/\(state.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                if let count = state.currentMemberCount {
                    Text("\(count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !state.perGroupErrors.isEmpty {
                    Text("\(state.perGroupErrors.count) group(s) failed — they were skipped.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.15).ignoresSafeArea())
    }
}

// MARK: - Remediation card

private struct ProviderRemediationCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(iconColor)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.31, green: 0.27, blue: 0.90))
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}
