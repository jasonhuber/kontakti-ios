import Foundation
import SwiftData

// MARK: - PersonEntity

/// Cached representation of a Person for list display and offline reading.
/// Not every API field is persisted — only what's needed to render the list and cards.
@Model
final class PersonEntity {
    @Attribute(.unique) var id: String
    var firstName: String
    var lastName: String
    var fullName: String
    var email: String?
    var phone: String?
    var avatarUrl: String?
    var title: String?
    var relationshipStrength: String  // RelationshipStrength.rawValue
    var lastContactedAt: Date?
    var companyId: String?
    var companyName: String?
    /// Mirrors `Person.doNotContact`. Defaults to false so existing persisted
    /// rows from before this field existed migrate cleanly.
    var doNotContact: Bool = false
    var updatedAt: Date

    init(from person: Person) {
        self.id = person.id
        self.firstName = person.firstName
        self.lastName = person.lastName
        self.fullName = person.fullName
        self.email = person.email
        self.phone = person.phone
        self.avatarUrl = person.avatarUrl
        self.title = person.title
        self.relationshipStrength = person.relationshipStrength.rawValue
        self.lastContactedAt = person.lastContactedAt
        self.companyId = person.companyId
        self.companyName = person.company?.name
        self.doNotContact = person.doNotContact
        self.updatedAt = person.updatedAt
    }

    /// Convenience mapping back to a lightweight Person-like struct for display.
    var displayStrength: RelationshipStrength {
        RelationshipStrength(rawValue: relationshipStrength) ?? .cold
    }
}

// MARK: - CompanyEntity

/// Cached representation of a Company for list display.
@Model
final class CompanyEntity {
    @Attribute(.unique) var id: String
    var name: String
    var domain: String?
    var logoUrl: String?
    var industry: String?
    var sizeRange: String?
    var peopleCount: Int
    var updatedAt: Date

    init(from company: Company) {
        self.id = company.id
        self.name = company.name
        self.domain = company.domain
        self.logoUrl = company.logoUrl
        self.industry = company.industry
        self.sizeRange = company.sizeRange
        self.peopleCount = company.peopleCount ?? 0
        self.updatedAt = company.updatedAt
    }
}

// MARK: - DiscussionEntity

/// Cached representation of a Discussion.
@Model
final class DiscussionEntity {
    @Attribute(.unique) var id: String
    var title: String
    var date: Date
    var type: String  // DiscussionType.rawValue
    var summary: String?
    var updatedAt: Date

    init(from discussion: Discussion) {
        self.id = discussion.id
        self.title = discussion.title
        self.date = discussion.date
        self.type = discussion.type.rawValue
        self.summary = discussion.summary
        self.updatedAt = discussion.updatedAt
    }

    var displayType: DiscussionType {
        DiscussionType(rawValue: type) ?? .other
    }
}

// MARK: - AppleContactLinkEntity

/// Local-only mapping between a Kontakti `Person.id` and an Apple Contacts
/// `CNContact.identifier`. Drives the "update / create / link" writeback
/// actions in PersonDetailView.
///
/// Why local-only: the same Kontakti person can map to different `CNContact.identifier`
/// values on different devices (iCloud Contacts assigns per-store identifiers,
/// and a contact deleted+re-imported has a fresh identifier). Syncing this
/// mapping through the backend would just cause cross-device confusion. Each
/// device decides for itself which Apple contact a Person points at.
@Model
final class AppleContactLinkEntity {
    @Attribute(.unique) var personId: String
    var cnContactIdentifier: String
    var updatedAt: Date

    init(personId: String, cnContactIdentifier: String, updatedAt: Date = Date()) {
        self.personId = personId
        self.cnContactIdentifier = cnContactIdentifier
        self.updatedAt = updatedAt
    }
}
