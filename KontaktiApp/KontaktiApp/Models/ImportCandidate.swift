import Foundation

/// Source of an import candidate — drives copy in ImportContactsView.
enum ImportSource {
    case device
    case gmail
}

/// A contact candidate gathered from the device or Gmail, not yet in Kontakti.
struct ImportCandidate: Identifiable, Codable, Hashable {
    var id: String { email ?? "\(firstName) \(lastName)" }
    let firstName: String
    let lastName: String
    let email: String?
    let phone: String?
    let organizationName: String?
}

// MARK: - Bulk import request

struct BulkImportRequest: Encodable {
    let contacts: [ImportCandidate]
}
