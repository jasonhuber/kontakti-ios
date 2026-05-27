import Foundation

// MARK: - Enrichment Models

struct EnrichmentRequest: Encodable {
    let url: String
    let html: String?
}

struct EnrichmentResult: Decodable {
    let person: EnrichedPerson
    let source: String
    let model: String?
}

struct EnrichedPerson: Decodable {
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let linkedinUrl: String?
    let avatarUrl: String?
    let title: String?
    let company: EnrichedCompany?
    let metadata: EnrichedMetadata?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phone
        case linkedinUrl = "linkedin_url"
        case avatarUrl = "avatar_url"
        case title
        case company
        case metadata
    }
}

struct EnrichedCompany: Decodable {
    let name: String?
    let domain: String?
    let industry: String?
    let sizeRange: String?
    let linkedinUrl: String?
    let website: String?

    enum CodingKeys: String, CodingKey {
        case name
        case domain
        case industry
        case sizeRange = "size_range"
        case linkedinUrl = "linkedin_url"
        case website
    }
}

struct EnrichedMetadata: Decodable {
    let location: String?
    let headline: String?
    let summary: String?
}

// MARK: - Enrichment Error

enum EnrichmentError: LocalizedError {
    case invalidURL
    case networkError(String)
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .networkError(let msg): return msg
        case .serverError(let code): return "Server error (\(code)). Please try again."
        case .decodingError: return "Unexpected response from enrichment service."
        }
    }
}

// MARK: - Enrichment Service

final class EnrichmentService {
    static let shared = EnrichmentService()
    private init() {}

    private let baseURL = URL(string: "https://enrich.kontakti.app")!

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    func enrich(linkedinURL: String, html: String? = nil) async throws -> EnrichmentResult {
        guard let url = URL(string: "/api/enrich", relativeTo: baseURL)
                .flatMap({ URL(string: $0.absoluteString) }) ?? URL(string: "https://enrich.kontakti.app/api/enrich") else {
            throw EnrichmentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(EnrichmentSecrets.apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = try encoder.encode(EnrichmentRequest(url: linkedinURL, html: html))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EnrichmentError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnrichmentError.networkError("No response received.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw EnrichmentError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(EnrichmentResult.self, from: data)
        } catch {
            throw EnrichmentError.decodingError
        }
    }
}
