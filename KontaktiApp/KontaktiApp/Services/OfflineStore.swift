import Foundation
import SwiftData
import UIKit

/// Singleton wrapper around the SwiftData ModelContext.
/// Reads and writes cached records used when the API is unreachable.
@MainActor
final class OfflineStore {
    static let shared = OfflineStore()

    private var context: ModelContext {
        PersistenceController.shared.container.mainContext
    }

    private init() {}

    func hasCachedData() -> Bool {
        !fetchPeople().isEmpty || !fetchCompanies().isEmpty || !fetchDiscussions().isEmpty
    }

    /// Wipes all locally cached data (people, companies, discussions).
    /// Call this on logout or after a server-side data wipe so stale records
    /// don't survive the next load cycle.
    ///
    /// Apple Contacts links are also cleared — they're per-device-and-user, so
    /// signing out as one user shouldn't leave the next user with stray links.
    func clearAll() {
        try? context.delete(model: PersonEntity.self)
        try? context.delete(model: CompanyEntity.self)
        try? context.delete(model: DiscussionEntity.self)
        try? context.delete(model: AppleContactLinkEntity.self)
        try? context.save()
    }

    // MARK: - People

    func fetchPeople() -> [PersonEntity] {
        let descriptor = FetchDescriptor<PersonEntity>(
            sortBy: [SortDescriptor(\.fullName)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func upsertPeople(_ people: [Person]) {
        let existingIds = Set(fetchPeople().map(\.id))
        for person in people {
            if existingIds.contains(person.id) {
                let personId = person.id
                // Update in-place by finding and mutating the existing entity
                var descriptor = FetchDescriptor<PersonEntity>(
                    predicate: #Predicate { $0.id == personId }
                )
                descriptor.fetchLimit = 1
                if let entity = try? context.fetch(descriptor).first {
                    entity.firstName = person.firstName
                    entity.lastName = person.lastName
                    entity.fullName = person.fullName
                    entity.email = person.email
                    entity.phone = person.phone
                    entity.avatarUrl = person.avatarUrl
                    entity.title = person.title
                    entity.relationshipStrength = person.relationshipStrength.rawValue
                    entity.lastContactedAt = person.lastContactedAt
                    entity.companyId = person.companyId
                    entity.companyName = person.company?.name
                    entity.doNotContact = person.doNotContact
                    entity.updatedAt = person.updatedAt
                }
            } else {
                context.insert(PersonEntity(from: person))
            }
        }
        try? context.save()
    }

    // MARK: - Companies

    func fetchCompanies() -> [CompanyEntity] {
        let descriptor = FetchDescriptor<CompanyEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func upsertCompanies(_ companies: [Company]) {
        let existingIds = Set(fetchCompanies().map(\.id))
        for company in companies {
            if existingIds.contains(company.id) {
                let companyId = company.id
                var descriptor = FetchDescriptor<CompanyEntity>(
                    predicate: #Predicate { $0.id == companyId }
                )
                descriptor.fetchLimit = 1
                if let entity = try? context.fetch(descriptor).first {
                    entity.name = company.name
                    entity.domain = company.domain
                    entity.logoUrl = company.logoUrl
                    entity.industry = company.industry
                    entity.sizeRange = company.sizeRange
                    entity.peopleCount = company.peopleCount ?? 0
                    entity.updatedAt = company.updatedAt
                }
            } else {
                context.insert(CompanyEntity(from: company))
            }
        }
        try? context.save()
    }

    // MARK: - Discussions

    func fetchDiscussions() -> [DiscussionEntity] {
        let descriptor = FetchDescriptor<DiscussionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func upsertDiscussions(_ discussions: [Discussion]) {
        let existingIds = Set(fetchDiscussions().map(\.id))
        for discussion in discussions {
            if existingIds.contains(discussion.id) {
                let discussionId = discussion.id
                var descriptor = FetchDescriptor<DiscussionEntity>(
                    predicate: #Predicate { $0.id == discussionId }
                )
                descriptor.fetchLimit = 1
                if let entity = try? context.fetch(descriptor).first {
                    entity.title = discussion.title
                    entity.date = discussion.date
                    entity.type = discussion.type.rawValue
                    entity.summary = discussion.summary
                    entity.updatedAt = discussion.updatedAt
                }
            } else {
                context.insert(DiscussionEntity(from: discussion))
            }
        }
        try? context.save()
    }

    // MARK: - Known emails (for deduplication)

    /// Returns the set of all cached email addresses (lowercased).
    func cachedEmails() -> Set<String> {
        let people = fetchPeople()
        return Set(people.compactMap { $0.email?.lowercased() })
    }

    // MARK: - Apple Contacts link mapping
    //
    // Local-only mapping (`kontakti_person_id -> CNContact.identifier`) used by
    // AppleContactsWriter. See AppleContactLinkEntity for the why-local-only
    // rationale; in short, CNContact identifiers are per-device and would just
    // diverge across devices if the backend tried to be the source of truth.

    /// Returns the linked Apple Contacts identifier for a Kontakti person,
    /// or `nil` if there's no link yet.
    func appleContactIdentifier(for personId: String) -> String? {
        var descriptor = FetchDescriptor<AppleContactLinkEntity>(
            predicate: #Predicate { $0.personId == personId }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first)?.cnContactIdentifier
    }

    /// Upserts the `(personId -> CNContact.identifier)` mapping.
    /// If the user has opted into cloud backup, also queues a backend sync.
    func setAppleContactIdentifier(_ identifier: String, for personId: String) {
        var descriptor = FetchDescriptor<AppleContactLinkEntity>(
            predicate: #Predicate { $0.personId == personId }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.cnContactIdentifier = identifier
            existing.updatedAt = Date()
        } else {
            context.insert(AppleContactLinkEntity(personId: personId, cnContactIdentifier: identifier))
        }
        try? context.save()

        if AppleContactLinkBackup.isEnabled {
            Task {
                let record = AppleContactLinkRecord(
                    personId: personId,
                    cnContactIdentifier: identifier,
                    deviceLabel: UIDevice.current.name,
                    updatedAt: nil
                )
                try? await APIClient.shared.bulkUpsertAppleContactLinks([record])
            }
        }
    }

    /// Removes the Apple Contacts link for a person, if any.
    func clearAppleContactIdentifier(for personId: String) {
        var descriptor = FetchDescriptor<AppleContactLinkEntity>(
            predicate: #Predicate { $0.personId == personId }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }

        if AppleContactLinkBackup.isEnabled {
            Task { try? await APIClient.shared.deleteAppleContactLink(personId: personId) }
        }
    }

    /// Fetches all links from the backend and restores any that are missing locally.
    /// Call on app launch when `AppleContactLinkBackup.isEnabled`.
    func restoreAppleContactLinksFromCloud() async {
        guard let links = try? await APIClient.shared.listAppleContactLinks() else { return }
        for link in links {
            if appleContactIdentifier(for: link.personId) == nil {
                var descriptor = FetchDescriptor<AppleContactLinkEntity>(
                    predicate: #Predicate { $0.personId == link.personId }
                )
                descriptor.fetchLimit = 1
                if (try? context.fetch(descriptor).first) == nil {
                    context.insert(AppleContactLinkEntity(
                        personId: link.personId,
                        cnContactIdentifier: link.cnContactIdentifier
                    ))
                }
            }
        }
        try? context.save()
    }
}

// MARK: - AppleContactLinkBackup

/// Thin UserDefaults wrapper so the toggle value is accessible from
/// OfflineStore without importing SwiftUI.
enum AppleContactLinkBackup {
    private static let key = "backup_apple_contact_links"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
