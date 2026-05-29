import Foundation
import Contacts

// MARK: - Errors

enum AppleContactsWriterError: LocalizedError {
    case notAuthorized
    case contactNotFound
    case noChanges
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Kontakti can't access your contacts. Enable Contacts in Settings > Privacy > Contacts."
        case .contactNotFound:
            return "The linked Apple contact couldn't be found. It may have been deleted on this device."
        case .noChanges:
            return "Nothing new to push — the Apple contact already matches."
        case .writeFailed(let msg):
            return msg
        }
    }
}

// MARK: - Field diff model

/// One row in the diff sheet shown before any writeback. `before` is the
/// Apple Contacts side, `after` is the Kontakti side we'd write in.
struct ContactFieldDiff: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let before: String
    let after: String
}

// MARK: - AppleContactsWriter

/// Reads `CNContact`s the user has linked to Kontakti people and pushes
/// enriched field values back into Apple Contacts via `CNSaveRequest`.
///
/// Architectural notes (intentional, not accidental):
///
///   1. Writeback is never silent. Every save path goes through a diff sheet
///      in the UI (or an explicit Create/Link action). We don't even expose
///      a "auto-sync on edit" toggle here, because the user data we'd be
///      mutating lives outside Kontakti.
///
///   2. The `personId -> CNContact.identifier` mapping is local-only — the
///      backend never sees `CNContact.identifier`. The identifier is a
///      per-device, per-store value (different on the user's other iPhone,
///      different again after a delete+reimport), and rebroadcasting it
///      through Kontakti would cause cross-device confusion. Each device
///      maintains its own mapping table; see `AppleContactLinkEntity`.
///
///   3. Pulling in enriched fields *also* depends on the per-field "is this
///      empty or different on the Apple side?" check inside `diff(...)`.
///      We never overwrite a non-empty Apple field with a Kontakti value
///      that just disagrees — we only push when the Apple side is empty or
///      the user explicitly chooses to overwrite via the diff confirmation.
@MainActor
final class AppleContactsWriter {
    static let shared = AppleContactsWriter()

    private let store = CNContactStore()

    private init() {}

    // MARK: - Authorization

    /// Returns true once the user has granted full or limited Contacts access.
    /// Callers should hide the writeback UI when this returns false rather
    /// than auto-prompting — the prompt has already been shown during import.
    func hasContactsAccess() -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    /// Ensures Contacts access is granted, prompting the user if needed.
    private func requireAccess() async throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let granted = try await store.requestAccess(for: .contacts)
            if !granted { throw AppleContactsWriterError.notAuthorized }
        case .denied, .restricted:
            throw AppleContactsWriterError.notAuthorized
        @unknown default:
            throw AppleContactsWriterError.notAuthorized
        }
    }

    // MARK: - Mapping helpers

    /// Returns the linked Apple identifier for a Kontakti person, or nil.
    func linkedIdentifier(for person: Person) -> String? {
        OfflineStore.shared.appleContactIdentifier(for: person.id)
    }

    /// Stores the local `Person -> CNContact.identifier` mapping. Does not
    /// touch the Apple contact itself.
    func link(person: Person, to contactID: String) {
        OfflineStore.shared.setAppleContactIdentifier(contactID, for: person.id)
    }

    /// Removes the local link for a person.
    func unlink(person: Person) {
        OfflineStore.shared.clearAppleContactIdentifier(for: person.id)
    }

    // MARK: - Diff

    /// Returns rows describing what would change if we applied this Person
    /// to the linked Apple contact. Only fields whose Apple value would be
    /// *set* or *replaced* by a meaningful Kontakti value are returned.
    /// Empty-to-empty changes and Kontakti-side blanks are skipped — we don't
    /// want a confirm sheet that says "nothing to do".
    func diff(person: Person, against contactID: String) -> [ContactFieldDiff] {
        guard let contact = try? fetchContact(identifier: contactID) else {
            return []
        }

        var rows: [ContactFieldDiff] = []

        // Names
        if let v = nonBlank(person.firstName), v != contact.givenName {
            rows.append(.init(label: "First name", before: displayValue(contact.givenName), after: v))
        }
        if let v = nonBlank(person.lastName), v != contact.familyName {
            rows.append(.init(label: "Last name", before: displayValue(contact.familyName), after: v))
        }

        // Company / title
        if let v = person.company?.name, let after = nonBlank(v), after != contact.organizationName {
            rows.append(.init(label: "Company", before: displayValue(contact.organizationName), after: after))
        }
        if let v = nonBlank(person.title), v != contact.jobTitle {
            rows.append(.init(label: "Title", before: displayValue(contact.jobTitle), after: v))
        }
        if let v = nonBlank(person.jobDepartment), v != contact.departmentName {
            rows.append(.init(label: "Department", before: displayValue(contact.departmentName), after: v))
        }

        // Primary email — only push if Apple side has no matching email.
        if let primaryEmail = primaryEmail(of: person),
           !contact.emailAddresses.contains(where: { ($0.value as String).lowercased() == primaryEmail.lowercased() })
        {
            rows.append(.init(
                label: "Email",
                before: displayValue(contact.emailAddresses.first.map { String($0.value) } ?? ""),
                after: primaryEmail
            ))
        }

        // Primary phone — same idea, comparing on digits only so formatting
        // differences don't read as a meaningful diff.
        if let primaryPhone = primaryPhone(of: person) {
            let keyDigits = digitsOnly(primaryPhone)
            let existing = contact.phoneNumbers
                .map { digitsOnly($0.value.stringValue) }
            if !keyDigits.isEmpty, !existing.contains(keyDigits) {
                rows.append(.init(
                    label: "Phone",
                    before: displayValue(contact.phoneNumbers.first?.value.stringValue ?? ""),
                    after: primaryPhone
                ))
            }
        }

        // LinkedIn — stored as a urlAddress with label "LinkedIn".
        if let linkedin = nonBlank(person.linkedinUrl) {
            let existing = contact.urlAddresses
                .map { String($0.value).lowercased() }
            if !existing.contains(linkedin.lowercased()) {
                let beforeFirst = contact.urlAddresses.first.map { String($0.value) } ?? ""
                rows.append(.init(label: "LinkedIn", before: displayValue(beforeFirst), after: linkedin))
            }
        }

        // Birthday — only push when Apple has none, since the user's birthday
        // on iCloud is the source of truth more often than ours.
        if let bday = person.birthday,
           contact.birthday?.date == nil
        {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            rows.append(.init(label: "Birthday", before: "empty", after: formatter.string(from: bday)))
        }

        // Note — append Kontakti's notes if Apple's note doesn't already contain
        // a matching substring. We're conservative: don't overwrite, just add.
        if let kontaktiNotes = nonBlank(person.notes) {
            let appleNote = contact.note
            if !appleNote.contains(kontaktiNotes) {
                rows.append(.init(
                    label: "Note",
                    before: displayValue(appleNote),
                    after: appleNote.isEmpty ? kontaktiNotes : "\(appleNote)\n\n\(kontaktiNotes)"
                ))
            }
        }

        return rows
    }

    // MARK: - Update existing

    /// Applies the Kontakti person's enrichable fields onto the linked Apple
    /// contact and persists via `CNSaveRequest`. Callers MUST present the
    /// diff sheet first and only invoke this on user confirmation.
    func update(person: Person, into contactID: String) async throws {
        try await requireAccess()

        let contact = try fetchContact(identifier: contactID)
        guard let mutable = contact.mutableCopy() as? CNMutableContact else {
            throw AppleContactsWriterError.writeFailed("Could not prepare contact for update.")
        }

        applyMutation(person: person, into: mutable)

        let request = CNSaveRequest()
        request.update(mutable)
        do {
            try store.execute(request)
        } catch {
            throw AppleContactsWriterError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - Create new

    /// Creates a new Apple contact pre-filled from the Kontakti person and
    /// returns the new `CNContact.identifier`. Caller is responsible for
    /// invoking `link(...)` to store the mapping.
    @discardableResult
    func create(person: Person) async throws -> String {
        try await requireAccess()

        let mutable = CNMutableContact()
        applyMutation(person: person, into: mutable)

        // Apple requires *something* renderable. Backfill from email/phone if
        // the user somehow has a nameless Kontakti record.
        if mutable.givenName.isEmpty && mutable.familyName.isEmpty {
            if let email = primaryEmail(of: person) {
                mutable.givenName = email
            } else if let phone = primaryPhone(of: person) {
                mutable.givenName = phone
            } else {
                mutable.givenName = "Untitled"
            }
        }

        let request = CNSaveRequest()
        request.add(mutable, toContainerWithIdentifier: nil)
        do {
            try store.execute(request)
        } catch {
            throw AppleContactsWriterError.writeFailed(error.localizedDescription)
        }
        return mutable.identifier
    }

    // MARK: - Mutation core
    //
    // Shared by both `update` and `create`. Only sets fields the Kontakti
    // person has meaningful values for — never clears an Apple field.

    private func applyMutation(person: Person, into c: CNMutableContact) {
        if let v = nonBlank(person.firstName) { c.givenName = v }
        if let v = nonBlank(person.lastName)  { c.familyName = v }
        if let v = nonBlank(person.nickname)  { c.nickname = v }

        if let v = person.company?.name, let cname = nonBlank(v) {
            c.organizationName = cname
        }
        if let v = nonBlank(person.title)         { c.jobTitle = v }
        if let v = nonBlank(person.jobDepartment) { c.departmentName = v }

        // Emails — merge by lowercased value so we don't duplicate.
        if let email = primaryEmail(of: person) {
            let lc = email.lowercased()
            let exists = c.emailAddresses.contains { ($0.value as String).lowercased() == lc }
            if !exists {
                c.emailAddresses.append(CNLabeledValue(label: CNLabelHome, value: email as NSString))
            }
        }

        // Phones — merge by digits-only.
        if let phone = primaryPhone(of: person) {
            let key = digitsOnly(phone)
            let exists = c.phoneNumbers.contains { digitsOnly($0.value.stringValue) == key }
            if !exists, !key.isEmpty {
                c.phoneNumbers.append(CNLabeledValue(
                    label: CNLabelPhoneNumberMobile,
                    value: CNPhoneNumber(stringValue: phone)
                ))
            }
        }

        // LinkedIn URL stored under "LinkedIn" label so it shows up cleanly
        // in the Contacts app.
        if let linkedin = nonBlank(person.linkedinUrl) {
            let lc = linkedin.lowercased()
            let exists = c.urlAddresses.contains { String($0.value).lowercased() == lc }
            if !exists {
                c.urlAddresses.append(CNLabeledValue(label: "LinkedIn", value: linkedin as NSString))
            }
        }

        // Birthday only if Apple side has none — see `diff(...)` for the
        // rationale (iCloud birthdays usually beat ours).
        if let bday = person.birthday, c.birthday?.date == nil {
            let cal = Calendar(identifier: .gregorian)
            let comps = cal.dateComponents([.year, .month, .day], from: bday)
            var birthday = DateComponents()
            birthday.year = comps.year
            birthday.month = comps.month
            birthday.day = comps.day
            c.birthday = birthday
        }

        // Notes — append rather than replace, so we don't trample any
        // hand-written Apple Contacts notes from before Kontakti existed.
        if let kontaktiNotes = nonBlank(person.notes) {
            if c.note.isEmpty {
                c.note = kontaktiNotes
            } else if !c.note.contains(kontaktiNotes) {
                c.note = "\(c.note)\n\n\(kontaktiNotes)"
            }
        }
    }

    // MARK: - Contact fetch

    /// Fetches a `CNContact` by identifier with all keys we care about.
    /// Throws `.contactNotFound` if the user deleted the contact on-device.
    private func fetchContact(identifier: String) throws -> CNContact {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactDepartmentNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
        ]
        do {
            return try store.unifiedContact(withIdentifier: identifier, keysToFetch: keys)
        } catch {
            throw AppleContactsWriterError.contactNotFound
        }
    }

    // MARK: - Field helpers

    private func nonBlank(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func displayValue(_ s: String) -> String {
        s.isEmpty ? "empty" : s
    }

    private func digitsOnly(_ s: String) -> String {
        let digits = s.filter { $0.isNumber }
        // Strip a leading US country code "1" on 11-digit numbers so that
        // "+1 555-1234" and "555-1234" compare equal — mirrors the dedup logic
        // already in PersonDetailView's `mergePhones`.
        if digits.count == 11 && digits.hasPrefix("1") { return String(digits.dropFirst()) }
        return digits
    }

    private func primaryEmail(of person: Person) -> String? {
        if let primary = person.emails.first(where: { $0.isPrimary }),
           let v = nonBlank(primary.value) {
            return v
        }
        if let first = person.emails.first, let v = nonBlank(first.value) { return v }
        return nonBlank(person.email)
    }

    private func primaryPhone(of person: Person) -> String? {
        if let primary = person.phones.first(where: { $0.isPrimary }),
           let v = nonBlank(primary.value) {
            return v
        }
        if let first = person.phones.first, let v = nonBlank(first.value) { return v }
        return nonBlank(person.phone)
    }
}
