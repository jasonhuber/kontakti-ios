import SwiftUI
import Contacts
import ContactsUI

// MARK: - AppleContactsWritebackSection
//
// Detail-screen panel that exposes the three explicit writeback actions:
//
//   • Update Apple Contact   — only shown when a CN identifier is linked.
//   • Create Apple Contact   — only shown when no link exists.
//   • Link to existing       — always shown so the user can switch link targets.
//
// Hidden entirely when the person is marked do-not-contact, when Contacts
// access hasn't been granted, or when the underlying CN entry was deleted
// after the link was stored (i.e. fetching by identifier throws).
struct AppleContactsWritebackSection: View {
    let person: Person
    var onLinkChanged: (() -> Void)? = nil

    @State private var linkedID: String?
    @State private var pendingDiff: PendingDiff?
    @State private var showContactPicker = false
    @State private var inFlight = false
    @State private var alert: AlertContent?

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    private let writer = AppleContactsWriter.shared

    var body: some View {
        // Hide entirely for do-not-contact people (per spec) and when we
        // don't have Contacts access yet — we don't want this section to
        // double as another permission prompt surface.
        if person.doNotContact || !writer.hasContactsAccess() {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Apple Contacts")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                GroupBox {
                    VStack(spacing: 0) {
                        if let id = linkedID {
                            Button { Task { await prepareDiff(for: id) } } label: {
                                actionRow(
                                    icon: "arrow.up.doc",
                                    title: "Update Apple Contact",
                                    subtitle: "Push enriched fields with a diff confirmation"
                                )
                            }
                            .disabled(inFlight)

                            Divider().padding(.leading, 36)

                            Button { showContactPicker = true } label: {
                                actionRow(
                                    icon: "link",
                                    title: "Change linked contact",
                                    subtitle: "Point to a different Apple contact"
                                )
                            }
                            .disabled(inFlight)
                        } else {
                            Button { Task { await createNewContact() } } label: {
                                actionRow(
                                    icon: "plus.circle",
                                    title: "Create Apple Contact",
                                    subtitle: "Add this person to your iPhone contacts"
                                )
                            }
                            .disabled(inFlight)

                            Divider().padding(.leading, 36)

                            Button { showContactPicker = true } label: {
                                actionRow(
                                    icon: "link.badge.plus",
                                    title: "Link to existing Apple Contact",
                                    subtitle: "Pick an existing iPhone contact"
                                )
                            }
                            .disabled(inFlight)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .task { refreshLink() }
            .onChange(of: person.id) { refreshLink() }
            .sheet(item: $pendingDiff) { pending in
                AppleContactsDiffSheet(
                    personName: person.fullName,
                    rows: pending.rows,
                    isSaving: inFlight,
                    onConfirm: { Task { await commitUpdate(contactID: pending.contactID) } },
                    onCancel: { pendingDiff = nil }
                )
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerSheet { picked in
                    showContactPicker = false
                    if let id = picked {
                        writer.link(person: person, to: id)
                        linkedID = id
                        onLinkChanged?()
                    }
                }
            }
            .alert(item: $alert) { content in
                Alert(title: Text(content.title), message: Text(content.message))
            }
        }
    }

    // MARK: - Actions

    private func refreshLink() {
        linkedID = writer.linkedIdentifier(for: person)
    }

    private func prepareDiff(for contactID: String) async {
        inFlight = true
        defer { inFlight = false }
        let rows = writer.diff(person: person, against: contactID)
        if rows.isEmpty {
            alert = AlertContent(
                title: "Already up to date",
                message: "The Apple contact already has these values — nothing to push."
            )
            return
        }
        pendingDiff = PendingDiff(contactID: contactID, rows: rows)
    }

    private func commitUpdate(contactID: String) async {
        inFlight = true
        defer { inFlight = false }
        do {
            try await writer.update(person: person, into: contactID)
            pendingDiff = nil
            alert = AlertContent(title: "Updated", message: "Apple Contacts now has the latest values from Kontakti.")
        } catch let err as AppleContactsWriterError {
            if case .contactNotFound = err {
                // The link is stale — drop it so the UI offers Create / Link again.
                writer.unlink(person: person)
                linkedID = nil
                onLinkChanged?()
            }
            alert = AlertContent(title: "Couldn't update", message: err.localizedDescription)
        } catch {
            alert = AlertContent(title: "Couldn't update", message: error.localizedDescription)
        }
    }

    private func createNewContact() async {
        inFlight = true
        defer { inFlight = false }
        do {
            let newID = try await writer.create(person: person)
            writer.link(person: person, to: newID)
            linkedID = newID
            onLinkChanged?()
            alert = AlertContent(title: "Created", message: "\(person.fullName) was added to Apple Contacts.")
        } catch {
            alert = AlertContent(title: "Couldn't create", message: error.localizedDescription)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(indigo)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if inFlight {
                ProgressView().scaleEffect(0.8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 10)
    }
}

// MARK: - Diff sheet

private struct PendingDiff: Identifiable {
    let id = UUID()
    let contactID: String
    let rows: [ContactFieldDiff]
}

struct AppleContactsDiffSheet: View {
    let personName: String
    let rows: [ContactFieldDiff]
    let isSaving: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("These fields on your iPhone contact for \(personName) will change. Nothing else is touched.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            diffRow(row)
                            if idx < rows.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)

                    Button {
                        onConfirm()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            }
                            Text(isSaving ? "Updating…" : "Update Apple Contact")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(indigo)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Confirm changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    @ViewBuilder
    private func diffRow(_ row: ContactFieldDiff) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(.secondary)
            HStack(alignment: .center, spacing: 8) {
                Text(row.before)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .strikethrough(row.before != "empty")
                    .lineLimit(2)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(row.after)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Contact picker

/// SwiftUI wrapper around `CNContactPickerViewController`. The picker handles
/// its own permission prompt and search UI, so the user can pick an existing
/// Apple contact without leaving the writeback flow.
private struct ContactPickerSheet: UIViewControllerRepresentable {
    let onPicked: (String?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let vc = CNContactPickerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPicked: (String?) -> Void
        init(onPicked: @escaping (String?) -> Void) { self.onPicked = onPicked }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPicked(contact.identifier)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onPicked(nil)
        }
    }
}

// MARK: - Alert helper

private struct AlertContent: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
