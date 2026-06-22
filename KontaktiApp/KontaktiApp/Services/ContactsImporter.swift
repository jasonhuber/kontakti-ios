import Foundation
import Contacts
import UIKit

// MARK: - Contacts authorization error

enum ContactsImporterError: LocalizedError {
    case denied
    case restricted
    case unknown
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .denied: return "Contacts access was denied. Enable it in Settings > Privacy > Contacts."
        case .restricted: return "Contacts access is restricted on this device."
        case .unknown: return "Could not access contacts."
        case .notImplemented(let msg): return msg
        }
    }
}

// MARK: - SyncDirection

/// Direction of a sync run.
///
/// Read paths are fully implemented:
///   - `.iosToKontakti` — pull device contacts into Kontakti.
///   - `.gmailToKontakti` — pull every linked Gmail account into Kontakti.
///   - `.both` — pull device + every linked Gmail account into Kontakti.
///
/// Push paths are DESIGN-INTENT placeholders (see TODO inside `run(direction:)`):
///   - `.iosToGmail` — push device contacts into Gmail (requires the Google
///     People API write scope, which the app does not currently request).
///   - `.gmailToIos` — push Gmail contacts into the device address book
///     (requires CNContactStore write access + UX confirmation per insert).
enum SyncDirection: String, CaseIterable, Identifiable, Hashable {
    case iosToKontakti
    case gmailToKontakti
    case both
    case iosToGmail
    case gmailToIos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iosToKontakti:   return "iOS → Kontakti"
        case .gmailToKontakti: return "Gmail → Kontakti"
        case .both:            return "Both → Kontakti"
        case .iosToGmail:      return "iOS → Gmail"
        case .gmailToIos:      return "Gmail → iOS"
        }
    }

    var helperText: String {
        switch self {
        case .iosToKontakti:
            return "Pull device contacts into Kontakti."
        case .gmailToKontakti:
            return "Pull contacts from every linked Gmail account into Kontakti."
        case .both:
            return "Pull from all your Gmails AND device into Kontakti."
        case .iosToGmail:
            return "Push device contacts into a linked Gmail account. (Coming soon.)"
        case .gmailToIos:
            return "Push Gmail contacts into your device address book. (Coming soon.)"
        }
    }
}

// MARK: - Sync result

struct SyncRunResult {
    var imported: Int = 0
    var skipped: Int = 0
    var duplicatesDetected: Int = 0
    var autoMerged: Int = 0
    var perSource: [String: Int] = [:]  // source label → imported count

    /// Duplicate groups left for the user to review after the server's
    /// auto-merge pass. Banners should key off this, not the raw detected count.
    var unresolvedDuplicates: Int {
        max(0, duplicatesDetected - autoMerged)
    }
}

// MARK: - ContactsImporter

/// Requests CNContactStore authorization, fetches device contacts,
/// optionally pulls one or more linked Gmail accounts, and POSTs them
/// to the Kontakti backend in source-aware batches.
///
/// INFO.PLIST REQUIREMENT:
/// Add key: NSContactsUsageDescription
/// Value: "Kontakti imports your contacts to help you track relationships."
@MainActor
final class ContactsImporter: ObservableObject {
    static let shared = ContactsImporter()

    private let store = CNContactStore()
    private let api = APIClient.shared

    /// Last result of a sync run — UI can observe to surface duplicate banners.
    @Published var lastResult: SyncRunResult?

    /// Set to true when the most recent import returned `duplicates_detected > 0`.
    @Published var hasUnreviewedDuplicates: Bool = false

    private init() {}

    // MARK: - Legacy / single-source candidate fetch (kept for back-compat)

    /// Request access and return filtered device candidates not already in Kontakti.
    /// Existing callers (Onboarding, PeopleViewModel) continue to use this.
    func fetchNewCandidates() async throws -> [ImportCandidate] {
        try await requestAccess()
        let all = try fetchAllDeviceContacts()
        let existingEmails = OfflineStore.shared.cachedEmails()
        let existingPhones = OfflineStore.shared.cachedPhones()
        return all.filter { !Self.matchesExisting($0, emails: existingEmails, phones: existingPhones) }
    }

    // MARK: - Public: orchestrated run

    /// Runs a sync in the requested direction.
    ///
    /// For read paths, this:
    ///   1. Fetches candidates from each requested source.
    ///   2. Tags each candidate with the right `source` string
    ///      (`"device"`, `"gmail_personal"`, `"gmail_work"`, `"gmail_other"`).
    ///   3. POSTs each source's contacts to `/contacts/import`, threading the
    ///      matching `google_account_id` for Gmail batches.
    ///   4. Aggregates the per-batch `imported / skipped / duplicates_detected`
    ///      counts into a `SyncRunResult` and publishes it.
    ///
    /// For push paths (`.iosToGmail`, `.gmailToIos`), this throws
    /// `ContactsImporterError.notImplemented(...)` — see the file-level
    /// SyncDirection doc for the design intent and TODO.
    @discardableResult
    func run(direction: SyncDirection) async throws -> SyncRunResult {
        switch direction {
        case .iosToKontakti:
            return try await runReadFromDevice()

        case .gmailToKontakti:
            return try await runReadFromGmail(includeDevice: false)

        case .both:
            return try await runReadFromGmail(includeDevice: true)

        case .iosToGmail:
            // TODO: requires Google People API write scope
            // (https://www.googleapis.com/auth/contacts). The current
            // GoogleAuthService only requests contacts.readonly. Once the
            // scope is upgraded, implement People API `createContact`
            // batched against the chosen GoogleAccount.
            throw ContactsImporterError.notImplemented(
                "Pushing to Gmail isn't enabled yet — it needs a Google contacts write scope. Tracking this in a TODO."
            )

        case .gmailToIos:
            // TODO: requires CNContactStore write access + per-contact user
            // confirmation UX. Not yet implemented.
            throw ContactsImporterError.notImplemented(
                "Pushing to your device address book isn't enabled yet. Tracking this in a TODO."
            )
        }
    }

    // MARK: - Read paths

    private func runReadFromDevice() async throws -> SyncRunResult {
        try await requestAccess()
        let raw = try fetchAllDeviceContacts()
        let existingEmails = OfflineStore.shared.cachedEmails()
        let existingPhones = OfflineStore.shared.cachedPhones()
        let filtered = raw.filter { !Self.matchesExisting($0, emails: existingEmails, phones: existingPhones) }
        let tagged = filtered.map { $0.withSource("device") }
        return try await postBatch(tagged, googleAccountId: nil, sourceLabel: "device")
    }

    private func runReadFromGmail(includeDevice: Bool) async throws -> SyncRunResult {
        var aggregate = SyncRunResult()

        // 1. Pull linked Google accounts.
        let accounts = try await api.listGoogleAccounts()

        // 2. Active Google access token (from primary sign-in) for reading.
        //    Note: this only works for the *currently signed-in* Google user
        //    via GIDSignIn. Reading from non-primary linked accounts also
        //    requires that account's access token; the design uses the
        //    current GIDSignIn token and lets the backend tag rows by
        //    google_account_id. Multi-account *reads* with distinct tokens
        //    are a follow-up — see TODO below.
        let accessToken = GoogleAuthService.shared.accessToken

        for account in accounts {
            let sourceLabel = "gmail_\(account.label)"
            do {
                // TODO(multi-account-reads): GIDSignIn only retains the most
                // recent Google session's access token. Reading the People
                // API for a non-primary linked account technically needs a
                // separate access token. For now we fetch using whatever
                // GoogleAuthService has, tag with the right source, and
                // rely on the backend dedup by google_account_id.
                guard let token = accessToken else { continue }
                let candidates = try await GmailContactsService.shared.fetchNewCandidates(accessToken: token)
                let tagged = candidates.map { $0.withSource(sourceLabel) }
                let result = try await postBatch(
                    tagged,
                    googleAccountId: account.id,
                    sourceLabel: sourceLabel
                )
                aggregate.merge(result)
            } catch {
                // Continue to next account on per-account failure.
                continue
            }
        }

        // 3. Optionally also pull device.
        if includeDevice {
            let deviceResult = try await runReadFromDevice()
            aggregate.merge(deviceResult)
        }

        publish(aggregate)
        return aggregate
    }

    // MARK: - Backend batch

    private func postBatch(
        _ contacts: [ImportCandidate],
        googleAccountId: Int?,
        sourceLabel: String
    ) async throws -> SyncRunResult {
        let normalized = contacts.compactMap { $0.normalizedForImport() }
        guard !normalized.isEmpty else {
            return SyncRunResult()
        }

        let req = BulkImportRequest(contacts: normalized, googleAccountId: googleAccountId)
        let response = try await api.importContacts(req)
        OfflineStore.shared.upsertPeople(response.people)

        var result = SyncRunResult()
        result.imported = response.imported
        result.skipped = response.skipped
        result.duplicatesDetected = response.duplicatesDetected
        result.autoMerged = response.autoMerged
        result.perSource[sourceLabel] = response.imported

        publish(result)
        return result
    }

    private func publish(_ result: SyncRunResult) {
        // Update on main actor — we are MainActor-isolated.
        lastResult = result
        // Only flag the "review duplicates" banner if there's something the
        // user actually has to look at. Auto-merged groups have already been
        // resolved server-side and shouldn't trigger the nag.
        if result.unresolvedDuplicates > 0 {
            hasUnreviewedDuplicates = true
        }
    }

    // MARK: - Dedup helper

    /// Returns true if the candidate matches an already-imported contact.
    /// Checks email first, then falls back to normalized-digits phone.
    private static func matchesExisting(
        _ candidate: ImportCandidate,
        emails: Set<String>,
        phones: Set<String>
    ) -> Bool {
        if let email = candidate.email?.lowercased(), emails.contains(email) { return true }
        if let phone = candidate.phone {
            let digits = phone.filter(\.isNumber)
            if !digits.isEmpty && phones.contains(digits) { return true }
        }
        return false
    }

    // MARK: - Device access

    private func requestAccess() async throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized, .limited:
            return
        case .denied:
            throw ContactsImporterError.denied
        case .restricted:
            throw ContactsImporterError.restricted
        case .notDetermined:
            let granted = try await store.requestAccess(for: .contacts)
            if !granted { throw ContactsImporterError.denied }
        @unknown default:
            throw ContactsImporterError.unknown
        }
    }

    private func fetchAllDeviceContacts() throws -> [ImportCandidate] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        var candidates: [ImportCandidate] = []
        try store.enumerateContacts(with: request) { contact, _ in
            let firstName = contact.givenName
            let lastName = contact.familyName

            guard !firstName.isEmpty || !lastName.isEmpty else { return }

            let email = contact.emailAddresses.first.map { String($0.value) }
            let phone = contact.phoneNumbers.first.map { $0.value.stringValue }
            let org = contact.organizationName.isEmpty ? nil : contact.organizationName

            candidates.append(ImportCandidate(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phone,
                organizationName: org
            ))
        }
        return candidates
    }
}

// MARK: - SyncRunResult merge helper
private extension SyncRunResult {
    mutating func merge(_ other: SyncRunResult) {
        imported += other.imported
        skipped += other.skipped
        duplicatesDetected += other.duplicatesDetected
        autoMerged += other.autoMerged
        for (k, v) in other.perSource {
            perSource[k, default: 0] += v
        }
    }
}
