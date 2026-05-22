import Foundation
import SwiftData

/// Singleton wrapper around the SwiftData ModelContext.
/// Reads and writes cached records used when the API is unreachable.
@MainActor
final class OfflineStore {
    static let shared = OfflineStore()

    private var context: ModelContext {
        PersistenceController.shared.container.mainContext
    }

    private init() {}

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
                // Update in-place by finding and mutating the existing entity
                var descriptor = FetchDescriptor<PersonEntity>(
                    predicate: #Predicate { $0.id == person.id }
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
                var descriptor = FetchDescriptor<CompanyEntity>(
                    predicate: #Predicate { $0.id == company.id }
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

    // MARK: - Known emails (for deduplication)

    /// Returns the set of all cached email addresses (lowercased).
    func cachedEmails() -> Set<String> {
        let people = fetchPeople()
        return Set(people.compactMap { $0.email?.lowercased() })
    }
}
