import Foundation

// MARK: - API Error
enum APIError: LocalizedError {
    case unauthorized
    case serverError(String)
    case noData
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please sign in again."
        case .serverError(let msg): return msg
        case .noData: return "No data received from server."
        case .invalidURL: return "Invalid URL."
        }
    }
}

// MARK: - API Client
final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = URL(string: "https://kontakti.app/api/v1")!
    private let keychain = KeychainService.shared

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Custom date decoding: try fractional seconds first, then plain ISO8601
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]

        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = fractionalFormatter.date(from: string) { return date }
            if let date = plainFormatter.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Core Request
    private func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = keychain.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        // 204 No Content — return EmptyResponse if T is EmptyResponse
        if httpResponse.statusCode == 204 {
            if let empty = EmptyResponse() as? T {
                return empty
            }
            // Try decoding empty data
            return try decoder.decode(T.self, from: Data("{}".utf8))
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.message)
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }

        if data.isEmpty {
            return try decoder.decode(T.self, from: Data("{}".utf8))
        }

        return try decoder.decode(T.self, from: data)
    }

    // Void-returning variant for endpoints that return 204 or irrelevant bodies
    private func requestVoid(
        _ endpoint: String,
        method: String,
        body: (any Encodable)? = nil
    ) async throws {
        let _: EmptyResponse = try await request(endpoint, method: method, body: body)
    }

    // MARK: - Auth
    func login(email: String, password: String) async throws -> LoginResponse {
        let req = LoginRequest(email: email, password: password)
        return try await request("auth/login", method: "POST", body: req)
    }

    func logout() async throws {
        try await requestVoid("auth/logout", method: "POST")
    }

    func me() async throws -> UserProfile {
        return try await request("auth/me")
    }

    // MARK: - People
    func listPeople(query: String? = nil, page: Int = 1) async throws -> Paginated<Person> {
        var items: [URLQueryItem] = [URLQueryItem(name: "page", value: "\(page)")]
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        return try await request("people", queryItems: items)
    }

    func getPerson(_ id: String) async throws -> Person {
        return try await request("people/\(id)")
    }

    func getTimeline(_ personId: String) async throws -> [TimelineEvent] {
        return try await request("people/\(personId)/timeline")
    }

    func getPersonDiscussions(_ id: String) async throws -> [Discussion] {
        return try await request("people/\(id)/discussions")
    }

    func getPersonTasks(_ id: String) async throws -> [KontaktiTask] {
        return try await request("people/\(id)/tasks")
    }

    // MARK: - Companies
    func listCompanies(query: String? = nil, page: Int = 1) async throws -> Paginated<Company> {
        var items: [URLQueryItem] = [URLQueryItem(name: "page", value: "\(page)")]
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        return try await request("companies", queryItems: items)
    }

    func getCompany(_ id: String) async throws -> Company {
        return try await request("companies/\(id)")
    }

    func getCompanyPeople(_ id: String) async throws -> [Person] {
        return try await request("companies/\(id)/people")
    }

    // MARK: - Discussions
    func listDiscussions(query: String? = nil, type: String? = nil, page: Int = 1) async throws -> Paginated<Discussion> {
        var items: [URLQueryItem] = [URLQueryItem(name: "page", value: "\(page)")]
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        if let t = type, !t.isEmpty { items.append(URLQueryItem(name: "type", value: t)) }
        return try await request("discussions", queryItems: items)
    }

    func getDiscussion(_ id: String) async throws -> Discussion {
        return try await request("discussions/\(id)")
    }

    func createDiscussion(_ req: CreateDiscussionRequest) async throws -> Discussion {
        return try await request("discussions", method: "POST", body: req)
    }

    // MARK: - Tasks
    func createTask(_ req: CreateTaskRequest) async throws -> KontaktiTask {
        return try await request("tasks", method: "POST", body: req)
    }

    func completeTask(_ id: String) async throws -> KontaktiTask {
        return try await request("tasks/\(id)/complete", method: "PATCH")
    }

    // MARK: - Feed
    func getFeed() async throws -> [FeedItem] {
        return try await request("feed")
    }

    // MARK: - Search
    func search(query: String) async throws -> SearchResponse {
        let items = [URLQueryItem(name: "q", value: query)]
        return try await request("search", queryItems: items)
    }

    // MARK: - Contacts Import

    /// Bulk-imports a set of device or Gmail candidates.
    /// Endpoint: POST /api/v1/contacts/import
    @discardableResult
    func importContacts(_ req: BulkImportRequest) async throws -> EmptyResponse {
        return try await request("contacts/import", method: "POST", body: req)
    }
}
