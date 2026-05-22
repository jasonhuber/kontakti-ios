import Foundation

// MARK: - Google People API response types

private struct GooglePeopleResponse: Decodable {
    let connections: [GooglePerson]?
}

private struct GooglePerson: Decodable {
    let names: [GoogleName]?
    let emailAddresses: [GoogleEmail]?
    let organizations: [GoogleOrg]?
    let phoneNumbers: [GooglePhone]?

    var primaryName: (first: String, last: String) {
        guard let name = names?.first(where: { $0.metadata?.primary == true }) ?? names?.first else {
            return ("", "")
        }
        return (name.givenName ?? "", name.familyName ?? "")
    }

    var primaryEmail: String? {
        (emailAddresses?.first(where: { $0.metadata?.primary == true }) ?? emailAddresses?.first)?.value
    }

    var primaryOrg: String? {
        organizations?.first?.name
    }

    var primaryPhone: String? {
        (phoneNumbers?.first(where: { $0.metadata?.primary == true }) ?? phoneNumbers?.first)?.value
    }
}

private struct GoogleName: Decodable {
    let givenName: String?
    let familyName: String?
    let metadata: GoogleFieldMetadata?
}

private struct GoogleEmail: Decodable {
    let value: String
    let metadata: GoogleFieldMetadata?
}

private struct GoogleOrg: Decodable {
    let name: String?
}

private struct GooglePhone: Decodable {
    let value: String
    let metadata: GoogleFieldMetadata?
}

private struct GoogleFieldMetadata: Decodable {
    let primary: Bool?
}

// MARK: - Gmail Messages API response types

private struct GmailListResponse: Decodable {
    let messages: [GmailMessageRef]?
}

private struct GmailMessageRef: Decodable {
    let id: String
}

private struct GmailMessage: Decodable {
    let payload: GmailPayload?
}

private struct GmailPayload: Decodable {
    let headers: [GmailHeader]?
}

private struct GmailHeader: Decodable {
    let name: String
    let value: String
}

// MARK: - GmailContactsService

/// Fetches contacts from Google People API and frequent senders from Gmail,
/// then deduplicates and returns candidates not already in the local cache.
final class GmailContactsService {
    static let shared = GmailContactsService()
    private init() {}

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // MARK: - Public API

    /// Fetches Google Contacts + frequent Gmail senders, deduplicates against cache.
    func fetchNewCandidates(accessToken: String) async throws -> [ImportCandidate] {
        async let contactsCandidates = fetchGoogleContacts(accessToken: accessToken)
        async let gmailCandidates = fetchGmailSenders(accessToken: accessToken)

        let (contacts, gmail) = try await (contactsCandidates, gmailCandidates)
        let merged = deduplicate(contacts + gmail)

        let existingEmails = await OfflineStore.shared.cachedEmails()
        return merged.filter { candidate in
            guard let email = candidate.email?.lowercased() else { return true }
            return !existingEmails.contains(email)
        }
    }

    // MARK: - Google People API

    private func fetchGoogleContacts(accessToken: String) async throws -> [ImportCandidate] {
        var components = URLComponents(string: "https://people.googleapis.com/v1/people/me/connections")!
        components.queryItems = [
            URLQueryItem(name: "personFields", value: "names,emailAddresses,organizations,phoneNumbers"),
            URLQueryItem(name: "pageSize", value: "1000"),
        ]

        let request = authorizedRequest(url: components.url!, token: accessToken)
        let (data, _) = try await session.data(for: request)
        let response = try decoder.decode(GooglePeopleResponse.self, from: data)

        return (response.connections ?? []).compactMap { person in
            let (first, last) = person.primaryName
            guard !first.isEmpty || !last.isEmpty else { return nil }
            return ImportCandidate(
                firstName: first,
                lastName: last,
                email: person.primaryEmail,
                phone: person.primaryPhone,
                organizationName: person.primaryOrg
            )
        }
    }

    // MARK: - Gmail frequent senders

    private func fetchGmailSenders(accessToken: String) async throws -> [ImportCandidate] {
        // Fetch up to 100 recent inbox messages
        var listComponents = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        listComponents.queryItems = [
            URLQueryItem(name: "maxResults", value: "100"),
            URLQueryItem(name: "labelIds", value: "INBOX"),
        ]

        let listRequest = authorizedRequest(url: listComponents.url!, token: accessToken)
        let (listData, _) = try await session.data(for: listRequest)
        let listResponse = try decoder.decode(GmailListResponse.self, from: listData)
        let messageIds = (listResponse.messages ?? []).map(\.id)

        // Fetch From: headers in parallel (batch up to 20 to avoid rate limits)
        var candidates: [ImportCandidate] = []
        let batchIds = Array(messageIds.prefix(20))

        await withTaskGroup(of: ImportCandidate?.self) { group in
            for msgId in batchIds {
                group.addTask { [weak self] in
                    try? await self?.extractSender(messageId: msgId, accessToken: accessToken)
                }
            }
            for await candidate in group {
                if let c = candidate { candidates.append(c) }
            }
        }

        return candidates
    }

    private func extractSender(messageId: String, accessToken: String) async throws -> ImportCandidate? {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
        ]

        let request = authorizedRequest(url: components.url!, token: accessToken)
        let (data, _) = try await session.data(for: request)
        let message = try decoder.decode(GmailMessage.self, from: data)

        guard let fromHeader = message.payload?.headers?.first(where: { $0.name == "From" }) else {
            return nil
        }

        return parseFromHeader(fromHeader.value)
    }

    /// Parses "Name <email>" or plain "email" format.
    private func parseFromHeader(_ raw: String) -> ImportCandidate? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if let ltRange = trimmed.range(of: "<"),
           let gtRange = trimmed.range(of: ">"),
           ltRange.upperBound <= gtRange.lowerBound {
            let namePart = String(trimmed[..<ltRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let email = String(trimmed[ltRange.upperBound..<gtRange.lowerBound]).lowercased()
            guard email.contains("@") else { return nil }

            let nameParts = namePart.split(separator: " ", maxSplits: 1)
            let firstName = nameParts.first.map(String.init) ?? ""
            let lastName = nameParts.dropFirst().first.map(String.init) ?? ""
            return ImportCandidate(firstName: firstName, lastName: lastName, email: email, phone: nil, organizationName: nil)
        }

        // Plain email only
        if trimmed.contains("@") {
            return ImportCandidate(firstName: trimmed, lastName: "", email: trimmed.lowercased(), phone: nil, organizationName: nil)
        }

        return nil
    }

    // MARK: - Helpers

    private func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func deduplicate(_ candidates: [ImportCandidate]) -> [ImportCandidate] {
        var seen = Set<String>()
        var result: [ImportCandidate] = []
        for candidate in candidates {
            let key = candidate.email?.lowercased() ?? "\(candidate.firstName)|\(candidate.lastName)"
            if seen.insert(key).inserted {
                result.append(candidate)
            }
        }
        return result
    }
}
