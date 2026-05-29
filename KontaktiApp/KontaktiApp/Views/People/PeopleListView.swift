import SwiftUI

struct PeopleListView: View {
    @StateObject private var vm = PeopleViewModel()
    @StateObject private var googleAuth = GoogleAuthService.shared
    @EnvironmentObject private var network: NetworkMonitor

    @State private var selectedStrength: RelationshipStrength? = nil
    @State private var showingGmailSignIn = false
    @State private var gmailError: String?

    private let strengthFilters: [RelationshipStrength?] = [nil, .close, .hot, .warm, .cold]

    private var filteredPeople: [Person] {
        guard let filter = selectedStrength else { return vm.people }
        return vm.people.filter { $0.relationshipStrength == filter }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Offline banner
                if !network.isConnected {
                    OfflineBanner()
                }

                // Import loading indicator
                if vm.isLoadingImport {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading contacts…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                }

                // Import error banner
                if let importError = vm.importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red)
                }

                // Strength filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(strengthFilters, id: \.self) { strength in
                            FilterPill(
                                label: strength?.label ?? "All",
                                isSelected: selectedStrength == strength
                            ) {
                                selectedStrength = strength
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color(.systemGroupedBackground))

                if vm.isLoading && vm.people.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredPeople.isEmpty && !vm.isLoading {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No contacts",
                        subtitle: "Add people to get started"
                    )
                } else {
                    List {
                        ForEach(filteredPeople) { person in
                            NavigationLink(value: person) {
                                PersonCardView(person: person)
                            }
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationDestination(for: Person.self) { person in
                        PersonDetailView(person: person)
                    }
                    .refreshable {
                        await vm.load(reset: true)
                    }
                }
            }
        }
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        vm.startDeviceImport()
                    } label: {
                        Label("Import from phone", systemImage: "iphone")
                    }

                    Button {
                        if googleAuth.isSignedIn, let token = googleAuth.accessToken {
                            vm.startGmailImport(accessToken: token)
                        } else {
                            showingGmailSignIn = true
                        }
                    } label: {
                        Label("Import from Gmail", systemImage: "envelope")
                    }

                    Button {
                        vm.showLinkedInImport = true
                    } label: {
                        Label("Import from LinkedIn", systemImage: "link.badge.plus")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .tint(Color(red: 0.31, green: 0.27, blue: 0.90))
            }
        }
        .searchable(text: $vm.searchText, prompt: "Search people")
        .onChange(of: vm.searchText) {
            vm.onSearchChange()
        }
        .task {
            await vm.load()
        }
        // LinkedIn import sheet
        .sheet(isPresented: $vm.showLinkedInImport) {
            LinkedInImportView {
                Task { await vm.load(reset: true) }
            }
        }
        // Import candidates sheet
        .sheet(isPresented: $vm.showingImportSheet) {
            ImportContactsView(
                source: vm.importSource,
                candidates: vm.importCandidates
            ) {
                // Refresh list after import
                Task { await vm.load(reset: true) }
            }
        }
        // Gmail sign-in sheet
        .sheet(isPresented: $showingGmailSignIn) {
            GoogleSignInSheet { token in
                showingGmailSignIn = false
                if let token {
                    vm.startGmailImport(accessToken: token)
                }
            }
        }
        // Gmail error alert
        .alert("Gmail Error", isPresented: Binding(
            get: { gmailError != nil },
            set: { if !$0 { gmailError = nil } }
        )) {
            Button("OK", role: .cancel) { gmailError = nil }
        } message: {
            Text(gmailError ?? "")
        }
    }
}

// MARK: - GoogleSignInSheet

/// Presents a sign-in prompt that triggers the Google OAuth flow.
/// Wraps UIKit's UIViewController context needed by GoogleSignIn SDK.
private struct GoogleSignInSheet: View {
    let onComplete: (String?) -> Void

    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "envelope.badge.person.crop")
                    .font(.system(size: 64))
                    .foregroundColor(Color(red: 0.31, green: 0.27, blue: 0.90))

                VStack(spacing: 8) {
                    Text("Connect Gmail")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Find contacts you email frequently and import them into Kontakti.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await signIn() }
                } label: {
                    HStack(spacing: 8) {
                        if isSigningIn {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "envelope")
                        }
                        Text(isSigningIn ? "Signing in…" : "Sign in with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 0.31, green: 0.27, blue: 0.90))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSigningIn)
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Gmail Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onComplete(nil) }
                }
            }
        }
    }

    private func signIn() async {
        isSigningIn = true
        errorMessage = nil

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            errorMessage = "Cannot present sign-in. Please try again."
            isSigningIn = false
            return
        }

        do {
            let token = try await GoogleAuthService.shared.signIn(presentingViewController: rootVC)
            onComplete(token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }
}

// MARK: - FilterPill

private struct FilterPill: View {
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
