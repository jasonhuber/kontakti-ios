import SwiftUI

/// Settings hub: linked Google accounts, sync direction, duplicate review.
struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject private var importer = ContactsImporter.shared

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        List {
            // MARK: Linked Google accounts
            Section {
                if vm.isLoadingAccounts {
                    HStack { ProgressView(); Text("Loading accounts…").foregroundColor(.secondary) }
                } else if vm.accounts.isEmpty {
                    Text("No Gmail accounts linked yet.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(vm.accounts) { account in
                        GoogleAccountRow(
                            account: account,
                            canUnlink: vm.canUnlink(account),
                            onMakePrimary: { Task { await vm.makePrimary(account) } },
                            onUnlink: { Task { await vm.unlink(account) } },
                            onChangeLabel: { newLabel in
                                Task { await vm.changeLabel(account, to: newLabel) }
                            }
                        )
                    }
                }

                Button {
                    Task { await vm.linkNewAccount() }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(vm.isLinking ? "Linking…" : "Link another Gmail account")
                    }
                }
                .disabled(vm.isLinking)
            } header: {
                Text("Linked Gmail accounts")
            } footer: {
                if let err = vm.accountsError {
                    Text(err).foregroundColor(.red)
                }
            }

            // MARK: Sync direction
            Section {
                NavigationLink {
                    SyncDirectionPicker(accounts: vm.accounts)
                } label: {
                    Label("Sync direction", systemImage: "arrow.left.arrow.right")
                }
            } header: {
                Text("Sync")
            }

            // MARK: Social groups
            Section {
                NavigationLink {
                    SocialGroupsListView()
                } label: {
                    Label("Social groups", systemImage: "person.3.sequence")
                }
                NavigationLink {
                    JobChangesView()
                } label: {
                    Label("Job changes", systemImage: "briefcase.badge.clock")
                }
            } header: {
                Text("Relationship engine")
            }

            // MARK: Duplicate review
            Section {
                NavigationLink {
                    DuplicateReviewView()
                } label: {
                    HStack {
                        Label("Review duplicates", systemImage: "person.2.crop.square.stack")
                        Spacer()
                        if importer.hasUnreviewedDuplicates {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                        }
                    }
                }
                NavigationLink {
                    ReviewContactsView()
                } label: {
                    Label("Review contacts", systemImage: "checkmark.shield")
                }
            }

            // MARK: Notifications
            Section {
                NotificationsSettingsRow()
                HStack {
                    Text("Device ID")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(AppDelegate.deviceId.prefix(8) + "…")
                        .font(.footnote.monospaced())
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Notifications")
            }

            // MARK: Account
            Section {
                Button(role: .destructive) {
                    Task { await authVM.logout() }
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .tint(indigo)
        .task { await vm.loadAccounts() }
        .refreshable { await vm.loadAccounts() }
    }
}

// MARK: - GoogleAccountRow

private struct GoogleAccountRow: View {
    let account: GoogleAccount
    let canUnlink: Bool
    let onMakePrimary: () -> Void
    let onUnlink: () -> Void
    let onChangeLabel: (String) -> Void

    @State private var showUnlinkAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(account.email)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if account.isPrimary {
                    Text("PRIMARY")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Picker("Label", selection: Binding(
                    get: { account.label },
                    set: { onChangeLabel($0) }
                )) {
                    Text("Personal").tag("personal")
                    Text("Work").tag("work")
                    Text("Other").tag("other")
                }
                .pickerStyle(.segmented)
            }

            if let lastSynced = account.lastSyncedAt {
                Text("Last synced: \(lastSynced)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                if !account.isPrimary {
                    Button("Make primary", action: onMakePrimary)
                        .font(.footnote)
                }
                Spacer()
                Button(role: .destructive) {
                    showUnlinkAlert = true
                } label: {
                    Text("Unlink").font(.footnote)
                }
                .disabled(!canUnlink)
            }
            if !canUnlink {
                Text("Unlink another account before removing your primary.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .alert("Unlink \(account.email)?", isPresented: $showUnlinkAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Unlink", role: .destructive, action: onUnlink)
        } message: {
            Text("Kontakti will stop syncing this Gmail account. You can re-link it later.")
        }
    }
}

// MARK: - SettingsViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var accounts: [GoogleAccount] = []
    @Published var isLoadingAccounts = false
    @Published var isLinking = false
    @Published var accountsError: String?

    private let api = APIClient.shared

    func loadAccounts() async {
        isLoadingAccounts = true
        accountsError = nil
        do {
            accounts = try await api.listGoogleAccounts()
        } catch {
            accountsError = error.localizedDescription
        }
        isLoadingAccounts = false
    }

    func canUnlink(_ account: GoogleAccount) -> Bool {
        if !account.isPrimary { return true }
        // Primary can only be unlinked if no other accounts exist (otherwise
        // you'd have orphan siblings).
        return accounts.count == 1
    }

    func linkNewAccount() async {
        isLinking = true
        accountsError = nil
        defer { isLinking = false }

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            accountsError = "Cannot present Google sign-in."
            return
        }
        do {
            let idToken = try await GoogleAuthService.shared.signInForLinking(presentingViewController: rootVC)
            _ = try await api.linkGoogleAccount(idToken: idToken, label: nil)
        } catch {
            accountsError = error.localizedDescription
        }
        // Always reload so the UI reflects actual server state, whether the
        // link succeeded, partially applied, or failed.
        await loadAccounts()
    }

    func makePrimary(_ account: GoogleAccount) async {
        do {
            _ = try await api.updateGoogleAccount(id: account.id, label: nil, isPrimary: true)
            await loadAccounts()
        } catch {
            accountsError = error.localizedDescription
        }
    }

    func unlink(_ account: GoogleAccount) async {
        do {
            try await api.unlinkGoogleAccount(id: account.id)
            await loadAccounts()
        } catch {
            accountsError = error.localizedDescription
        }
    }

    func changeLabel(_ account: GoogleAccount, to newLabel: String) async {
        guard newLabel != account.label else { return }
        do {
            _ = try await api.updateGoogleAccount(id: account.id, label: newLabel, isPrimary: nil)
            await loadAccounts()
        } catch {
            accountsError = error.localizedDescription
        }
    }
}

// MARK: - NotificationsSettingsRow

private struct NotificationsSettingsRow: View {
    @State private var enabled: Bool = UserDefaults.standard.string(forKey: AppDelegate.tokenDefaultsKey) != nil
    @State private var working = false

    var body: some View {
        Toggle(isOn: $enabled) {
            Label("Enable notifications", systemImage: "bell.badge")
        }
        .disabled(working)
        .onChange(of: enabled) { _, newValue in
            Task { await toggle(newValue) }
        }
    }

    private func toggle(_ on: Bool) async {
        working = true
        defer { working = false }
        if on {
            await AppDelegate.requestAndRegister()
        } else if let token = UserDefaults.standard.string(forKey: AppDelegate.tokenDefaultsKey) {
            do {
                try await APIClient.shared.unregisterPushToken(token: token)
                UserDefaults.standard.removeObject(forKey: AppDelegate.tokenDefaultsKey)
            } catch {
                print("[Push] Unregister failed: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(AuthViewModel())
}
