import SwiftUI

/// Presents a list of device or Gmail contacts not yet in Kontakti.
/// Supports multi-select and bulk import via POST /api/v1/contacts/import.
struct ImportContactsView: View {
    let source: ImportSource
    let candidates: [ImportCandidate]
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importSucceeded = false
    @State private var successTitle = "Imported!"
    @State private var successMessage = "Your selected contacts have been added to Kontakti."

    private let api = APIClient.shared

    private var sourceLabel: String {
        switch source {
        case .device: return "phone"
        case .gmail: return "Gmail"
        }
    }

    private var emptyTitle: String {
        switch source {
        case .device: return "All contacts imported"
        case .gmail: return "No new Gmail contacts"
        }
    }

    private var emptySubtitle: String {
        switch source {
        case .device: return "Everyone in your phone is already in Kontakti."
        case .gmail: return "All frequent email senders are already in Kontakti."
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: emptyTitle,
                        subtitle: emptySubtitle
                    )
                } else {
                    VStack(spacing: 0) {
                        if let error = importError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.red)
                        }

                        List(candidates) { candidate in
                            CandidateRow(
                                candidate: candidate,
                                isSelected: selected.contains(candidate.id)
                            ) {
                                if selected.contains(candidate.id) {
                                    selected.remove(candidate.id)
                                } else {
                                    selected.insert(candidate.id)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Import from \(sourceLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss?()
                    }
                }

                if !candidates.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task { await performImport() }
                        } label: {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(selected.isEmpty ? "Select all" : "Import \(selected.count)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isImporting)
                        .tint(Color(red: 0.31, green: 0.27, blue: 0.90))
                    }
                }
            }
            .alert(successTitle, isPresented: $importSucceeded) {
                Button("Done") {
                    dismiss()
                    onDismiss?()
                }
            } message: {
                Text(successMessage)
            }
        }
    }

    // MARK: - Import

    private func performImport() async {
        // "Select all" tap when nothing is selected
        if selected.isEmpty {
            selected = Set(candidates.map(\.id))
            return
        }

        let selectedCandidates = candidates.filter { selected.contains($0.id) }
        let toImport = selectedCandidates.compactMap { $0.normalizedForImport() }
        let skippedBeforeImport = selectedCandidates.count - toImport.count
        guard !toImport.isEmpty else {
            importError = "None of the selected contacts include enough information to import."
            return
        }

        isImporting = true
        importError = nil
        do {
            if NetworkMonitor.shared.isConnected {
                let result = try await api.importContacts(BulkImportRequest(contacts: toImport))
                await OfflineStore.shared.upsertPeople(result.people)
                successTitle = "Imported!"
                var msg = "Imported \(result.imported), skipped \(result.skipped + skippedBeforeImport)."
                if result.autoMerged > 0 {
                    msg += " Auto-merged \(result.autoMerged) duplicate\(result.autoMerged == 1 ? "" : "s")."
                }
                successMessage = msg + " Your contacts are synced to your Kontakti account."
            } else {
                for candidate in toImport {
                    await SyncQueue.shared.enqueue(.createPerson(candidate))
                }
                successTitle = "Queued!"
                successMessage = "These contacts will sync to your Kontakti account when you're back online."
            }
            importSucceeded = true
        } catch {
            importError = error.localizedDescription
        }
        isImporting = false
    }
}

// MARK: - CandidateRow

private struct CandidateRow: View {
    let candidate: ImportCandidate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar placeholder
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    Text(initials)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.systemGray))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(candidate.firstName) \(candidate.lastName)")
                        .font(.body)
                        .foregroundColor(.primary)
                    if let email = candidate.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let org = candidate.organizationName {
                        Text(org)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color(red: 0.31, green: 0.27, blue: 0.90) : Color(.systemGray4))
                    .font(.title3)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.secondarySystemGroupedBackground))
    }

    private var initials: String {
        let f = candidate.firstName.first.map(String.init) ?? ""
        let l = candidate.lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}
