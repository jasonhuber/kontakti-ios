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

// MARK: - AnyEncodable
/// Wraps an arbitrary `[String: Any]` so it can be passed through Codable's
/// type system. Encodes `String`, `Int`, `Double`, `Bool`, nested dicts/arrays,
/// and treats anything else as null.
struct AnyEncodable: Encodable {
    private let value: Any

    init(_ value: Any) { self.value = value }
    init(_ value: [String: Any]) { self.value = value }

    func encode(to encoder: Encoder) throws {
        try AnyEncodable.encode(value: value, to: encoder)
    }

    private static func encode(value: Any, to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Bool: try container.encode(v)
        case let v as [String: Any]:
            try container.encode(v.mapValues(AnyEncodable.init))
        case let v as [Any]:
            try container.encode(v.map(AnyEncodable.init))
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - API Client
final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = URL(string: "https://kontakti.app/api/v1")!
    /// Host root, used to resolve relative asset URLs returned by the API
    /// (e.g. `/photos/<personId>/<uuid>.jpg`). External URLs like LinkedIn's
    /// CDN are stored as-is and should pass through `absoluteURL(forAsset:)`.
    let assetBaseURL = URL(string: "https://kontakti.app")!
    private let keychain = KeychainService.shared

    /// Resolves an asset URL stored on the backend. If `path` is already an
    /// absolute http(s) URL it's returned as-is; otherwise it's joined onto
    /// `assetBaseURL`. Returns nil when the input is empty / malformed.
    func absoluteURL(forAsset path: String?) -> URL? {
        guard let p = path?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty else {
            return nil
        }
        if p.lowercased().hasPrefix("http://") || p.lowercased().hasPrefix("https://") {
            return URL(string: p)
        }
        let trimmed = p.hasPrefix("/") ? String(p.dropFirst()) : p
        return URL(string: trimmed, relativeTo: assetBaseURL)?.absoluteURL
    }

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

    func register(name: String, username: String, email: String, password: String) async throws -> LoginResponse {
        let req = RegisterRequest(name: name, username: username, email: email,
                                  password: password, passwordConfirmation: password)
        return try await request("auth/register", method: "POST", body: req)
    }

    func loginWithGoogle(idToken: String) async throws -> LoginResponse {
        let req = GoogleLoginRequest(idToken: idToken)
        return try await request("auth/google", method: "POST", body: req)
    }

    func logout() async throws {
        try await requestVoid("auth/logout", method: "POST")
    }

    func me() async throws -> UserProfile {
        return try await request("auth/me")
    }

    func completeOnboarding() async throws -> UserProfile {
        return try await request("auth/onboarding/complete", method: "POST")
    }

    // MARK: - People
    func listPeople(
        query: String? = nil,
        page: Int = 1,
        needsReview: Bool = false
    ) async throws -> Paginated<Person> {
        var items: [URLQueryItem] = [URLQueryItem(name: "page", value: "\(page)")]
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        if needsReview { items.append(URLQueryItem(name: "needs_review", value: "1")) }
        return try await request("people", queryItems: items)
    }

    func getPeopleHealth() async throws -> PeopleHealth {
        return try await request("people/health")
    }

    @discardableResult
    func markPersonReviewed(id: String) async throws -> Person {
        return try await request("people/\(id)/review", method: "POST")
    }

    func searchPeople(query: String) async throws -> [Person] {
        let response = try await listPeople(query: query)
        return response.data
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

    /// Patch a person with any subset of fields.
    /// Endpoint: PATCH /api/v1/people/{id}
    @discardableResult
    func updatePerson(id: String, patch: PersonPatch) async throws -> Person {
        return try await request("people/\(id)", method: "PATCH", body: patch)
    }

    /// Returns the notes attached to a person.
    /// Endpoint: GET /api/v1/people/{id}/notes
    func listNotesForPerson(id: String) async throws -> [Note] {
        return try await request("people/\(id)/notes")
    }

    // MARK: - Person Photos

    /// GET /api/v1/people/{id}/photos
    func listPhotos(personId: String) async throws -> [PersonPhoto] {
        return try await request("people/\(personId)/photos")
    }

    /// Multipart upload of a raw image file.
    /// POST /api/v1/people/{id}/photos with field name `file`.
    func uploadPhoto(
        personId: String,
        imageData: Data,
        mimeType: String,
        source: String = "manual_upload"
    ) async throws -> PersonPhoto {
        let url = baseURL.appendingPathComponent("people/\(personId)/photos")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = keychain.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let ext = mimeType.split(separator: "/").last.map(String.init) ?? "jpg"
        let filename = "photo-\(UUID().uuidString).\(ext)"

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(source)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            if let err = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(err.message)
            }
            throw APIError.serverError("HTTP \(http.statusCode)")
        }
        return try decoder.decode(PersonPhoto.self, from: data)
    }

    /// JSON upload via a `data:image/...;base64,...` URL — used by the share
    /// extension or clipboard paste flows.
    func uploadPhotoDataURL(
        personId: String,
        dataURL: String,
        source: String = "paste"
    ) async throws -> PersonPhoto {
        struct Body: Encodable {
            let data: String
            let source: String
        }
        return try await request(
            "people/\(personId)/photos",
            method: "POST",
            body: Body(data: dataURL, source: source)
        )
    }

    /// JSON upload via an external URL pointer (e.g. LinkedIn CDN). The
    /// backend stores the pointer without downloading.
    func uploadPhotoURL(
        personId: String,
        url: String,
        source: String = "linkedin"
    ) async throws -> PersonPhoto {
        struct Body: Encodable {
            let url: String
            let source: String
        }
        return try await request(
            "people/\(personId)/photos",
            method: "POST",
            body: Body(url: url, source: source)
        )
    }

    /// DELETE /api/v1/people/{id}/photos/{photo}
    func deletePhoto(personId: String, photoId: String) async throws {
        try await requestVoid("people/\(personId)/photos/\(photoId)", method: "DELETE")
    }

    /// POST /api/v1/people/{id}/photos/{photo}/primary
    @discardableResult
    func setPrimaryPhoto(personId: String, photoId: String) async throws -> PersonPhoto {
        return try await request(
            "people/\(personId)/photos/\(photoId)/primary",
            method: "POST"
        )
    }

    /// Returns the tasks attached to a person (alias for getPersonTasks for naming consistency).
    func listTasksForPerson(id: String) async throws -> [KontaktiTask] {
        return try await getPersonTasks(id)
    }

    // MARK: - Notes
    func createNote(personId: String, title: String?, body: String) async throws -> Note {
        let req = CreateNoteRequest(
            title: title,
            body: body,
            notableType: "App\\Models\\Person",
            notableId: personId
        )
        return try await request("notes", method: "POST", body: req)
    }

    func updateNote(id: String, title: String?, body: String) async throws -> Note {
        let req = UpdateNoteRequest(title: title, body: body)
        return try await request("notes/\(id)", method: "PATCH", body: req)
    }

    func deleteNote(id: String) async throws {
        try await requestVoid("notes/\(id)", method: "DELETE")
    }

    // MARK: - Person-scoped task / discussion helpers

    func createTask(
        personId: String,
        title: String,
        dueAt: Date?,
        priority: TaskPriority
    ) async throws -> KontaktiTask {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let req = CreateTaskRequest(
            title: title,
            dueAt: dueAt.map { iso.string(from: $0) },
            priority: priority.rawValue,
            taskableType: "App\\Models\\Person",
            taskableId: personId
        )
        return try await createTask(req)
    }

    func createDiscussionForPerson(
        personId: String,
        type: DiscussionType,
        happenedAt: Date,
        summary: String?,
        title: String? = nil
    ) async throws -> Discussion {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let derivedTitle: String = {
            if let t = title, !t.trimmingCharacters(in: .whitespaces).isEmpty { return t }
            return "\(type.label) on \(happenedAt.formatted(date: .abbreviated, time: .omitted))"
        }()
        let req = CreateDiscussionRequest(
            title: derivedTitle,
            date: iso.string(from: happenedAt),
            type: type.rawValue,
            summary: summary,
            participantIds: [personId]
        )
        return try await createDiscussion(req)
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
    func importContacts(_ req: BulkImportRequest) async throws -> ImportResult {
        return try await request("contacts/import", method: "POST", body: req)
    }

    // MARK: - Create Person

    /// Creates a single person record.
    /// Endpoint: POST /api/v1/people
    func createPerson(_ req: CreatePersonRequest) async throws -> Person {
        return try await request("people", method: "POST", body: req)
    }

    // MARK: - Google Accounts (multi-account linking)

    func listGoogleAccounts() async throws -> [GoogleAccount] {
        return try await request("google-accounts")
    }

    func linkGoogleAccount(idToken: String, label: String?) async throws -> GoogleAccount {
        let body = LinkGoogleAccountRequest(idToken: idToken, label: label)
        return try await request("google-accounts/link", method: "POST", body: body)
    }

    func updateGoogleAccount(id: Int, label: String?, isPrimary: Bool?) async throws -> GoogleAccount {
        let body = UpdateGoogleAccountRequest(label: label, isPrimary: isPrimary)
        return try await request("google-accounts/\(id)", method: "PATCH", body: body)
    }

    func unlinkGoogleAccount(id: Int) async throws {
        try await requestVoid("google-accounts/\(id)", method: "DELETE")
    }

    // MARK: - Duplicates

    func listDuplicates() async throws -> [DuplicateCandidate] {
        return try await request("duplicates")
    }

    func scanDuplicates() async throws -> (generated: Int, aiResolved: Int) {
        let res: ScanDuplicatesResponse = try await request("duplicates/scan", method: "POST")
        return (res.generated, res.aiResolved)
    }

    @discardableResult
    func mergeDuplicate(id: Int, primaryId: String, merged: MergedFields) async throws -> Person {
        let body = MergeDuplicateRequest(primaryId: primaryId, merged: merged)
        return try await request("duplicates/\(id)/merge", method: "POST", body: body)
    }

    func dismissDuplicate(id: Int) async throws {
        try await requestVoid("duplicates/\(id)/dismiss", method: "POST")
    }

    // MARK: - Today inbox

    /// Back-compat: returns only the `items` array. Decodes either the new
    /// envelope shape (`{items, count, quiz, rhythm_insights}`) or the
    /// legacy bare-array response.
    func listToday(limit: Int = 10) async throws -> [TodayItem] {
        let bundle = try await loadTodayWithQuiz(limit: limit)
        return bundle.items
    }

    /// New full-shape Today loader. Resilient to either the new envelope
    /// or the legacy bare-array response — falls back transparently so we
    /// don't break callers while the backend rolls out.
    func loadTodayWithQuiz(limit: Int = 25) async throws -> (
        items: [TodayItem],
        quiz: [ContactPrompt],
        rhythmInsights: [RhythmInsight]
    ) {
        let queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        // Try the new envelope first; fall back to the legacy bare-array
        // response shape on any decoding failure.
        do {
            let response: TodayResponse = try await request("today", queryItems: queryItems)
            return (response.items, response.quiz, response.rhythmInsights)
        } catch is DecodingError {
            let items: [TodayItem] = try await request("today", queryItems: queryItems)
            return (items, [], [])
        }
    }

    /// POST /quiz/{prompt}/answer — returns the updated person.
    /// `note` is an optional free-text note saved as a Note on the person so the
    /// AI can use it later to decide how/why to reach out.
    func answerQuiz(promptId: String, answer: String, structured: [String: Any]? = nil, note: String? = nil) async throws -> Person {
        struct Body: Encodable {
            let answer: String
            let structured: AnyEncodable?
            let note: String?
        }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = Body(
            answer: answer,
            structured: structured.map(AnyEncodable.init),
            note: (trimmedNote?.isEmpty == false) ? trimmedNote : nil
        )
        let response: PersonResponse = try await request("quiz/\(promptId)/answer", method: "POST", body: body)
        return response.person
    }

    /// POST /quiz/{prompt}/skip — 204.
    /// `permanent: true` tells the backend never to ask this prompt's
    /// question for this person again.
    func skipQuiz(promptId: String, permanent: Bool = false) async throws {
        if permanent {
            struct Body: Encodable { let permanent: Bool }
            try await requestVoid("quiz/\(promptId)/skip", method: "POST", body: Body(permanent: true))
        } else {
            try await requestVoid("quiz/\(promptId)/skip", method: "POST")
        }
    }

    /// GET /people/{id}/remembrances — answers the user previously gave.
    func listRemembrances(personId: String) async throws -> [PersonRemembrance] {
        return try await request("people/\(personId)/remembrances")
    }

    func draftMessage(itemKey: String) async throws -> String {
        let res: DraftMessageResponse = try await request("today/items/\(itemKey)/draft", method: "POST")
        return res.draft
    }

    struct LogReachOutBody: Encodable {
        let via: String
        let note: String?
    }

    @discardableResult
    func logReachOut(itemKey: String, via: String, note: String?) async throws -> Date? {
        let body = LogReachOutBody(via: via, note: note)
        let res: LogReachOutResponse = try await request("today/items/\(itemKey)/log", method: "POST", body: body)
        return res.lastContactedAt
    }

    // MARK: - Social Groups

    func listSocialGroups() async throws -> [SocialGroup] {
        return try await request("social-groups")
    }

    struct CreateSocialGroupBody: Encodable {
        let source: String
        let externalId: String
        let name: String?

        enum CodingKeys: String, CodingKey {
            case source
            case externalId = "external_id"
            case name
        }
    }

    func createSocialGroup(source: String, externalId: String, name: String?) async throws -> SocialGroup {
        let body = CreateSocialGroupBody(source: source, externalId: externalId, name: name)
        return try await request("social-groups", method: "POST", body: body)
    }

    func syncSocialGroup(id: String) async throws -> SocialGroupSyncResult {
        return try await request("social-groups/\(id)/sync", method: "POST")
    }

    func deleteSocialGroup(id: String) async throws {
        try await requestVoid("social-groups/\(id)", method: "DELETE")
    }

    // MARK: - Social Providers (Facebook / WhatsApp)

    /// Internal helper that allows 503 ProviderError responses to be parsed
    /// as a known state rather than thrown.
    private func providerRequest<T: Decodable>(
        _ endpoint: String,
        method: String = "GET"
    ) async throws -> Result<T, ProviderError> {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = keychain.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        if httpResponse.statusCode == 503 {
            if let providerErr = try? decoder.decode(ProviderError.self, from: data) {
                return .failure(providerErr)
            }
            throw APIError.serverError("Provider unavailable (503)")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.message)
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
        let decoded = try decoder.decode(T.self, from: data)
        return .success(decoded)
    }

    private struct FacebookGroupsResponse: Decodable {
        let groups: [FacebookGroup]
    }

    private struct WhatsappGroupsResponse: Decodable {
        let groups: [WhatsappGroup]
    }

    func listFacebookGroups() async throws -> Result<[FacebookGroup], ProviderError> {
        let res: Result<FacebookGroupsResponse, ProviderError> =
            try await providerRequest("social-providers/facebook/groups")
        return res.map { $0.groups }
    }

    func whatsappStatus() async throws -> WhatsappStatus {
        return try await request("social-providers/whatsapp/status")
    }

    func whatsappQR() async throws -> WhatsappQR {
        return try await request("social-providers/whatsapp/qr")
    }

    func listWhatsappGroups() async throws -> Result<[WhatsappGroup], ProviderError> {
        let res: Result<WhatsappGroupsResponse, ProviderError> =
            try await providerRequest("social-providers/whatsapp/my-groups")
        return res.map { $0.groups }
    }

    // MARK: - Social Activity

    func listActivity(personId: String) async throws -> [SocialActivity] {
        return try await request("people/\(personId)/activity")
    }

    func refreshActivity(personId: String) async throws -> [SocialActivity] {
        return try await request("people/\(personId)/activity/refresh", method: "POST")
    }

    func acknowledgeActivity(id: String) async throws {
        try await requestVoid("activity/\(id)/acknowledge", method: "POST")
    }

    // MARK: - Job change detection

    func detectJobChanges() async throws -> JobDetectionResult {
        return try await request("jobs/detect-changes", method: "POST")
    }

    // MARK: - Voice capture

    func captureVoice(audioURL: URL, personId: String?, context: String?) async throws -> VoiceCaptureResult {
        let url = baseURL.appendingPathComponent("voice/capture")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = keychain.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body = Data()
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        let audioData = try Data(contentsOf: audioURL)
        let filename = audioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        if let personId { appendField(name: "person_id", value: personId) }
        if let context, !context.isEmpty { appendField(name: "context", value: context) }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            if let err = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(err.message)
            }
            throw APIError.serverError("HTTP \(http.statusCode)")
        }
        return try decoder.decode(VoiceCaptureResult.self, from: data)
    }

    // MARK: - Push registration

    func registerPushToken(deviceToken: Data, deviceId: String?) async throws {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        let body = RegisterPushTokenRequest(platform: "ios", token: hex, deviceId: deviceId)
        try await requestVoid("push/register", method: "POST", body: body)
    }

    func unregisterPushToken(token: String) async throws {
        let body = UnregisterPushTokenRequest(token: token)
        try await requestVoid("push/register", method: "DELETE", body: body)
    }
}

// MARK: - Voice capture models

struct VoiceCaptureResult: Decodable {
    let transcript: String
    let summary: String
    let discussions: [Discussion]
    let tasks: [KontaktiTask]
    let personRefs: [PersonRef]

    enum CodingKeys: String, CodingKey {
        case transcript, summary, discussions, tasks
        case personRefs = "person_refs"
    }

    struct PersonRef: Decodable, Identifiable {
        let nameHint: String
        let action: String
        let suggestedHandle: String?
        var id: String { nameHint }

        enum CodingKeys: String, CodingKey {
            case nameHint = "name_hint"
            case action
            case suggestedHandle = "suggested_handle"
        }
    }
}

// Workaround: the spec uses `TaskItem` — alias to existing KontaktiTask.
typealias TaskItem = KontaktiTask

// MARK: - Push registration models

private struct RegisterPushTokenRequest: Encodable {
    let platform: String
    let token: String
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case platform, token
        case deviceId = "device_id"
    }
}

private struct UnregisterPushTokenRequest: Encodable {
    let token: String
}

// MARK: - Google Account Models

struct GoogleAccount: Identifiable, Decodable, Hashable {
    let id: Int
    let email: String
    let label: String          // "personal" | "work" | "other"
    let isPrimary: Bool
    let avatarUrl: String?
    let lastSyncedAt: String?  // ISO-ish string from server; left as String to avoid date strictness

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case label
        case isPrimary = "is_primary"
        case avatarUrl = "avatar_url"
        case lastSyncedAt = "last_synced_at"
    }
}

struct LinkGoogleAccountRequest: Encodable {
    let idToken: String
    let label: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case label
    }
}

struct UpdateGoogleAccountRequest: Encodable {
    let label: String?
    let isPrimary: Bool?

    enum CodingKeys: String, CodingKey {
        case label
        case isPrimary = "is_primary"
    }
}

// MARK: - Duplicate Models

struct MergedFields: Codable, Hashable {
    var firstName: String?
    var lastName: String?
    var email: String?
    var phone: String?
    var companyName: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phone
        case companyName = "company_name"
    }
}

struct AIDecision: Decodable, Hashable {
    let decision: String
    let confidence: Double
    let primaryId: String
    let merged: MergedFields
    let reasoning: String

    enum CodingKeys: String, CodingKey {
        case decision
        case confidence
        case primaryId = "primary_id"
        case merged
        case reasoning
    }
}

struct DuplicateCandidate: Identifiable, Decodable, Hashable {
    let id: Int
    let personIds: [String]
    let status: String
    let aiDecision: AIDecision?
    let aiConfidence: Double?
    let people: [Person]

    enum CodingKeys: String, CodingKey {
        case id
        case personIds = "person_ids"
        case status
        case aiDecision = "ai_decision"
        case aiConfidence = "ai_confidence"
        case people
    }
}

private struct ScanDuplicatesResponse: Decodable {
    let generated: Int
    let aiResolved: Int

    enum CodingKeys: String, CodingKey {
        case generated
        case aiResolved = "ai_resolved"
    }
}

private struct MergeDuplicateRequest: Encodable {
    let primaryId: String
    let merged: MergedFields

    enum CodingKeys: String, CodingKey {
        case primaryId = "primary_id"
        case merged
    }
}

// MARK: - CreatePersonRequest

struct CreatePersonRequest: Encodable {
    let firstName: String
    let lastName: String?
    let email: String?
    let phone: String?
    let linkedinUrl: String?
    let avatarUrl: String?
    let title: String?
    let companyName: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phone
        case linkedinUrl = "linkedin_url"
        case avatarUrl = "avatar_url"
        case title
        case companyName = "company_name"
        case notes
    }
}

// MARK: - Social Provider Models

struct FacebookGroup: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let url: String
    let memberCount: Int?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, url
        case memberCount = "member_count"
        case avatarUrl = "avatar_url"
    }
}

struct WhatsappGroup: Identifiable, Codable, Hashable {
    let jid: String
    var id: String { jid }
    let name: String
    let memberCount: Int?
    let avatarUrl: String?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case jid, name
        case memberCount = "member_count"
        case avatarUrl = "avatar_url"
        case isAdmin = "is_admin"
    }
}

struct WhatsappStatus: Codable {
    let paired: Bool
    let phoneNumber: String?
    let qrRequired: Bool

    enum CodingKeys: String, CodingKey {
        case paired
        case phoneNumber = "phone_number"
        case qrRequired = "qr_required"
    }
}

struct WhatsappQR: Codable {
    let paired: Bool
    let qrDataUrl: String?
    let expiresInSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case paired
        case qrDataUrl = "qr_data_url"
        case expiresInSeconds = "expires_in_seconds"
    }
}

struct ProviderError: Codable, Error {
    let error: String
    let remediation: String?
}
