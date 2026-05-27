import Foundation

/// Source of an import candidate — drives copy in ImportContactsView.
enum ImportSource {
    case device
    case gmail
}

/// A simple label+value pair used for import-side emails/phones/urls.
struct ImportLabeledValue: Codable, Hashable {
    let value: String
    let label: String
}

/// Address payload for imports, matching the backend `addresses[]` shape.
struct ImportAddress: Codable, Hashable {
    let label: String
    let street: String
    let city: String
    let region: String
    let postalCode: String
    let country: String

    enum CodingKeys: String, CodingKey {
        case label
        case street
        case city
        case region
        case postalCode = "postal_code"
        case country
    }
}

/// A contact candidate gathered from the device or Gmail, not yet in Kontakti.
///
/// `source` is an optional backend-recognized tag like `"device"`, `"gmail"`,
/// `"gmail_personal"`, `"gmail_work"`, `"gmail_other"`. When present, it is
/// serialized as `source` on the per-contact JSON payload.
///
/// The struct keeps legacy `email`/`phone` scalar fields for back-compat with
/// the original importer; the backend will accept either the scalars OR the
/// `emails: []` / `phones: []` arrays.
struct ImportCandidate: Identifiable, Codable, Hashable {
    var id: String { email ?? "\(firstName) \(lastName)" }
    let firstName: String
    let lastName: String
    let nickname: String?
    let email: String?
    let phone: String?
    let organizationName: String?
    let jobTitle: String?
    let jobDepartment: String?
    let birthday: String?           // "YYYY-MM-DD"
    let deviceNote: String?
    let emails: [ImportLabeledValue]?
    let phones: [ImportLabeledValue]?
    let addresses: [ImportAddress]?
    let urls: [ImportLabeledValue]?
    var source: String? = nil

    // Backend expects snake_case field names
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName  = "last_name"
        case nickname
        case email
        case phone
        case organizationName = "company_name"
        case jobTitle = "title"
        case jobDepartment = "job_department"
        case birthday
        case deviceNote = "device_note"
        case emails
        case phones
        case addresses
        case urls
        case source
    }

    init(
        firstName: String,
        lastName: String,
        nickname: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        organizationName: String? = nil,
        jobTitle: String? = nil,
        jobDepartment: String? = nil,
        birthday: String? = nil,
        deviceNote: String? = nil,
        emails: [ImportLabeledValue]? = nil,
        phones: [ImportLabeledValue]? = nil,
        addresses: [ImportAddress]? = nil,
        urls: [ImportLabeledValue]? = nil,
        source: String? = nil
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.nickname = nickname
        self.email = email
        self.phone = phone
        self.organizationName = organizationName
        self.jobTitle = jobTitle
        self.jobDepartment = jobDepartment
        self.birthday = birthday
        self.deviceNote = deviceNote
        self.emails = emails
        self.phones = phones
        self.addresses = addresses
        self.urls = urls
        self.source = source
    }

    /// Encode only non-nil arrays so payloads stay compact and the backend's
    /// back-compat path can keep using the legacy `email` / `phone` scalars.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(firstName, forKey: .firstName)
        try c.encode(lastName, forKey: .lastName)
        try c.encodeIfPresent(nickname, forKey: .nickname)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(phone, forKey: .phone)
        try c.encodeIfPresent(organizationName, forKey: .organizationName)
        try c.encodeIfPresent(jobTitle, forKey: .jobTitle)
        try c.encodeIfPresent(jobDepartment, forKey: .jobDepartment)
        try c.encodeIfPresent(birthday, forKey: .birthday)
        try c.encodeIfPresent(deviceNote, forKey: .deviceNote)
        if let emails, !emails.isEmpty { try c.encode(emails, forKey: .emails) }
        if let phones, !phones.isEmpty { try c.encode(phones, forKey: .phones) }
        if let addresses, !addresses.isEmpty { try c.encode(addresses, forKey: .addresses) }
        if let urls, !urls.isEmpty { try c.encode(urls, forKey: .urls) }
        try c.encodeIfPresent(source, forKey: .source)
    }

    func normalizedForImport() -> ImportCandidate? {
        let normalizedEmail = Self.clean(email)?.lowercased()
        let normalizedPhone = Self.clean(phone)
        var firstName = Self.clean(firstName) ?? ""
        var lastName = Self.clean(lastName) ?? ""

        if firstName.isEmpty && !lastName.isEmpty {
            firstName = lastName
            lastName = ""
        }

        if firstName.isEmpty, let normalizedEmail {
            firstName = normalizedEmail
                .split(separator: "@", maxSplits: 1)
                .first
                .map { String($0).replacingOccurrences(of: ".", with: " ") } ?? normalizedEmail
        }

        if firstName.isEmpty, let normalizedPhone {
            firstName = normalizedPhone
        }

        guard !firstName.isEmpty else {
            return nil
        }

        return ImportCandidate(
            firstName: String(firstName.prefix(100)),
            lastName: String(lastName.prefix(100)),
            nickname: Self.clean(nickname).map { String($0.prefix(100)) },
            email: normalizedEmail,
            phone: normalizedPhone.map { String($0.prefix(50)) },
            organizationName: Self.clean(organizationName).map { String($0.prefix(255)) },
            jobTitle: Self.clean(jobTitle).map { String($0.prefix(255)) },
            jobDepartment: Self.clean(jobDepartment).map { String($0.prefix(255)) },
            birthday: birthday,
            deviceNote: Self.clean(deviceNote),
            emails: emails,
            phones: phones,
            addresses: addresses,
            urls: urls,
            source: source
        )
    }

    /// Returns a copy of this candidate with `source` set.
    func withSource(_ source: String?) -> ImportCandidate {
        ImportCandidate(
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            email: email,
            phone: phone,
            organizationName: organizationName,
            jobTitle: jobTitle,
            jobDepartment: jobDepartment,
            birthday: birthday,
            deviceNote: deviceNote,
            emails: emails,
            phones: phones,
            addresses: addresses,
            urls: urls,
            source: source
        )
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Bulk import request

struct BulkImportRequest: Encodable {
    let contacts: [ImportCandidate]
    let googleAccountId: Int?

    init(contacts: [ImportCandidate], googleAccountId: Int? = nil) {
        self.contacts = contacts
        self.googleAccountId = googleAccountId
    }

    enum CodingKeys: String, CodingKey {
        case contacts
        case googleAccountId = "google_account_id"
    }
}

struct ImportResult: Decodable {
    let imported: Int
    let skipped: Int
    let people: [Person]
    let duplicatesDetected: Int
    /// Duplicate groups the server auto-merged during the import (same phone
    /// or email → no human review needed). `duplicatesDetected - autoMerged`
    /// is the count that actually needs the user's attention.
    let autoMerged: Int

    enum CodingKeys: String, CodingKey {
        case imported
        case skipped
        case people
        case duplicatesDetected = "duplicates_detected"
        case autoMerged = "auto_merged"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imported = try container.decode(Int.self, forKey: .imported)
        skipped = try container.decode(Int.self, forKey: .skipped)
        people = try container.decodeIfPresent([Person].self, forKey: .people) ?? []
        duplicatesDetected = try container.decodeIfPresent(Int.self, forKey: .duplicatesDetected) ?? 0
        autoMerged = try container.decodeIfPresent(Int.self, forKey: .autoMerged) ?? 0
    }
}
