import SwiftUI
import Contacts

/// Picks a SyncDirection and runs `ContactsImporter.run(direction:)`.
///
/// Recommendation banners are computed lazily from a quick set-diff between
/// device emails and the user's already-cached Kontakti emails (proxy for
/// "what's in Gmail"). The full Gmail-vs-device diff is best computed
/// server-side; this view does a client-side approximation so the user gets
/// fast, actionable nudges.
struct SyncDirectionPicker: View {
    let accounts: [GoogleAccount]

    @StateObject private var importer = ObservableImporter()
    @State private var selected: SyncDirection = .iosToKontakti
    @State private var isRunning = false
    @State private var error: String?
    @State private var resultMessage: String?

    @State private var deviceNotInGmailCount: Int = 0
    @State private var perAccountGmailExtras: [Int: Int] = [:]

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        Form {
            Section {
                Picker("Direction", selection: $selected) {
                    ForEach(SyncDirection.allCases) { dir in
                        Text(dir.label).tag(dir)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()

                Text(selected.helperText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } header: {
                Text("Sync direction")
            }

            if deviceNotInGmailCount > 0 {
                Section {
                    RecommendationBanner(
                        text: "\(deviceNotInGmailCount) device contacts aren't in any Gmail — push them to Gmail?",
                        actionLabel: "Push to Gmail",
                        action: { selected = .iosToGmail }
                    )
                }
            }

            ForEach(accounts) { account in
                if let extras = perAccountGmailExtras[account.id], extras > 0 {
                    Section {
                        RecommendationBanner(
                            text: "\(extras) contacts from \(account.label.capitalized) Gmail aren't on this device — add to iOS?",
                            actionLabel: "Push to iOS",
                            action: { selected = .gmailToIos }
                        )
                    }
                }
            }

            Section {
                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        if isRunning {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Run sync now")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isRunning)

                if let result = resultMessage {
                    Text(result).font(.footnote).foregroundColor(.green)
                }
                if let err = error {
                    Text(err).font(.footnote).foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Sync direction")
        .navigationBarTitleDisplayMode(.inline)
        .tint(indigo)
        .task {
            await computeRecommendations()
        }
    }

    // MARK: - Run

    private func run() async {
        isRunning = true
        error = nil
        resultMessage = nil
        do {
            let result = try await ContactsImporter.shared.run(direction: selected)
            resultMessage = "Imported \(result.imported), skipped \(result.skipped). " +
                (result.duplicatesDetected > 0 ? "\(result.duplicatesDetected) possible duplicates found." : "")
        } catch let e as ContactsImporterError {
            error = e.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
        isRunning = false
    }

    // MARK: - Recommendations

    private func computeRecommendations() async {
        // 1. Best-effort device emails.
        let deviceEmails = (try? await fetchDeviceEmails()) ?? Set<String>()

        // 2. Cached "known to Kontakti" emails — proxies "already in some Gmail".
        let known = OfflineStore.shared.cachedEmails()

        let extras = deviceEmails.subtracting(known)
        deviceNotInGmailCount = extras.count

        // 3. Per-account "Gmail not on device" — would require querying each
        //    Gmail's contacts, which is expensive. Skipped here; left as a
        //    follow-up (the banner UI is wired and ready to display).
        perAccountGmailExtras = [:]
    }

    private func fetchDeviceEmails() async throws -> Set<String> {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized || status == .limited else { return [] }

        let store = CNContactStore()
        let keys = [CNContactEmailAddressesKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var emails = Set<String>()
        try store.enumerateContacts(with: request) { contact, _ in
            for entry in contact.emailAddresses {
                emails.insert(String(entry.value).lowercased())
            }
        }
        return emails
    }
}

// MARK: - RecommendationBanner

private struct RecommendationBanner: View {
    let text: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text(text).font(.subheadline)
            }
            Button(actionLabel, action: action)
                .font(.footnote.weight(.semibold))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Observable wrapper for the importer

/// Lightweight wrapper because SwiftUI needs a stable @StateObject; ContactsImporter
/// itself is @MainActor and already ObservableObject — re-exposing it.
@MainActor
private final class ObservableImporter: ObservableObject {
    let importer = ContactsImporter.shared
}

#Preview {
    NavigationStack {
        SyncDirectionPicker(accounts: [])
    }
}
