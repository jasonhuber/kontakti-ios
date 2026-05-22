import Foundation
import Contacts

// MARK: - Contacts authorization error

enum ContactsImporterError: LocalizedError {
    case denied
    case restricted
    case unknown

    var errorDescription: String? {
        switch self {
        case .denied: return "Contacts access was denied. Enable it in Settings > Privacy > Contacts."
        case .restricted: return "Contacts access is restricted on this device."
        case .unknown: return "Could not access contacts."
        }
    }
}

// MARK: - ContactsImporter

/// Requests CNContactStore authorization, fetches device contacts,
/// and deduplicates against the local SwiftData cache.
///
/// INFO.PLIST REQUIREMENT:
/// Add key: NSContactsUsageDescription
/// Value: "Kontakti imports your contacts to help you track relationships."
final class ContactsImporter {
    static let shared = ContactsImporter()
    private init() {}

    private let store = CNContactStore()

    /// Request access and return filtered candidates not already in Kontakti.
    func fetchNewCandidates() async throws -> [ImportCandidate] {
        try await requestAccess()
        let all = try fetchAll()
        let existingEmails = await OfflineStore.shared.cachedEmails()
        return all.filter { candidate in
            guard let email = candidate.email?.lowercased() else { return true }
            return !existingEmails.contains(email)
        }
    }

    // MARK: - Private

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

    private func fetchAll() throws -> [ImportCandidate] {
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

            // Skip entirely nameless contacts
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
