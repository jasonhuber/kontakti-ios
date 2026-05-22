import Foundation

// MARK: - Auth
struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable {
    let token: String
    let user: UserProfile
}

struct UserProfile: Decodable, Identifiable {
    let id: String
    let name: String
    let email: String
    let username: String?
}

// MARK: - Common
struct Paginated<T: Decodable>: Decodable {
    let data: [T]
    let total: Int
    let perPage: Int
    let currentPage: Int
    let lastPage: Int

    enum CodingKeys: String, CodingKey {
        case data
        case total
        case perPage = "per_page"
        case currentPage = "current_page"
        case lastPage = "last_page"
    }
}

struct Tag: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let slug: String
    let color: String
}

// MARK: - Person
enum RelationshipStrength: String, Decodable, CaseIterable {
    case cold, warm, hot, close

    var label: String { rawValue.capitalized }

    var color: String {
        switch self {
        case .cold: return "#71717A"
        case .warm: return "#D97706"
        case .hot: return "#EA580C"
        case .close: return "#16A34A"
        }
    }
}

struct Person: Decodable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let fullName: String
    let email: String?
    let phone: String?
    let linkedinUrl: String?
    let avatarUrl: String?
    let companyId: String?
    let company: Company?
    let title: String?
    let relationshipStrength: RelationshipStrength
    let lastContactedAt: Date?
    let nextFollowupAt: Date?
    let notes: String?
    let tags: [Tag]
    let discussionsCount: Int?
    let dealsCount: Int?
    let tasksCount: Int?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case email
        case phone
        case linkedinUrl = "linkedin_url"
        case avatarUrl = "avatar_url"
        case companyId = "company_id"
        case company
        case title
        case relationshipStrength = "relationship_strength"
        case lastContactedAt = "last_contacted_at"
        case nextFollowupAt = "next_followup_at"
        case notes
        case tags
        case discussionsCount = "discussions_count"
        case dealsCount = "deals_count"
        case tasksCount = "tasks_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Company
struct Company: Decodable, Identifiable {
    let id: String
    let name: String
    let domain: String?
    let logoUrl: String?
    let industry: String?
    let sizeRange: String?
    let linkedinUrl: String?
    let website: String?
    let notes: String?
    let tags: [Tag]
    let peopleCount: Int?
    let dealsCount: Int?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case domain
        case logoUrl = "logo_url"
        case industry
        case sizeRange = "size_range"
        case linkedinUrl = "linkedin_url"
        case website
        case notes
        case tags
        case peopleCount = "people_count"
        case dealsCount = "deals_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Discussion
enum DiscussionType: String, Decodable, CaseIterable {
    case call, meeting, email, message, event, other

    var label: String { rawValue.capitalized }

    var emoji: String {
        switch self {
        case .call: return "📞"
        case .meeting: return "🤝"
        case .email: return "📧"
        case .message: return "💬"
        case .event: return "📅"
        case .other: return "💡"
        }
    }
}

struct Discussion: Decodable, Identifiable {
    let id: String
    let title: String
    let date: Date
    let type: DiscussionType
    let summary: String?
    let body: String?
    let participants: [Person]?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case type
        case summary
        case body
        case participants
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateDiscussionRequest: Encodable {
    let title: String
    let date: String
    let type: String
    let summary: String?
    let participantIds: [String]?

    enum CodingKeys: String, CodingKey {
        case title
        case date
        case type
        case summary
        case participantIds = "participant_ids"
    }
}

// MARK: - Note
struct Note: Decodable, Identifiable {
    let id: String
    let title: String?
    let body: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Task
enum TaskPriority: String, Decodable {
    case low, medium, high, urgent
}

struct KontaktiTask: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let dueAt: Date?
    let completedAt: Date?
    let priority: TaskPriority
    let createdAt: Date
    let updatedAt: Date

    var isComplete: Bool { completedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case dueAt = "due_at"
        case completedAt = "completed_at"
        case priority
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateTaskRequest: Encodable {
    let title: String
    let dueAt: String?
    let priority: String
    let taskableType: String?
    let taskableId: String?

    enum CodingKeys: String, CodingKey {
        case title
        case dueAt = "due_at"
        case priority
        case taskableType = "taskable_type"
        case taskableId = "taskable_id"
    }
}

// MARK: - Timeline
struct TimelineEvent: Decodable, Identifiable {
    let id: UUID
    let type: String
    let date: Date
    let data: TimelineData

    enum CodingKeys: String, CodingKey {
        case type
        case date
        case data
    }

    init(from decoder: Decoder) throws {
        self.id = UUID()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.date = try container.decode(Date.self, forKey: .date)
        self.data = try container.decode(TimelineData.self, forKey: .data)
    }
}

enum TimelineData: Decodable {
    case discussion(Discussion)
    case note(Note)
    case task(KontaktiTask)
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Discussion.self) {
            self = .discussion(d)
            return
        }
        if let n = try? container.decode(Note.self) {
            self = .note(n)
            return
        }
        if let t = try? container.decode(KontaktiTask.self) {
            self = .task(t)
            return
        }
        self = .unknown
    }

    var title: String {
        switch self {
        case .discussion(let d): return d.title
        case .note(let n): return n.title ?? "Note"
        case .task(let t): return t.title
        case .unknown: return "Event"
        }
    }

    var subtitle: String {
        switch self {
        case .discussion(let d): return d.summary ?? d.type.label
        case .note(let n): return String(n.body.prefix(80))
        case .task(let t): return t.description ?? t.priority.rawValue.capitalized
        case .unknown: return ""
        }
    }

    var icon: String {
        switch self {
        case .discussion(let d): return d.type.emoji
        case .note: return "📝"
        case .task: return "✅"
        case .unknown: return "📌"
        }
    }
}

// MARK: - Feed
struct FeedItem: Decodable, Identifiable {
    let id: String
    let subjectType: String
    let subjectId: String
    let verb: String
    let payload: [String: AnyCodable]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case subjectType = "subject_type"
        case subjectId = "subject_id"
        case verb
        case payload
        case createdAt = "created_at"
    }

    var entityType: String {
        subjectType.components(separatedBy: "\\").last?.lowercased() ?? subjectType
    }

    var verbLabel: String {
        switch verb {
        case "created": return "created"
        case "updated": return "updated"
        case "contacted": return "contacted"
        case "task_completed": return "completed task on"
        default: return verb
        }
    }

    var entityName: String {
        (payload["name"]?.stringValue ?? payload["title"]?.stringValue) ?? entityType
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { value = v }
        else if let v = try? c.decode(Int.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(Bool.self) { value = v }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let v = value as? String { try c.encode(v) }
        else if let v = value as? Int { try c.encode(v) }
        else if let v = value as? Double { try c.encode(v) }
        else if let v = value as? Bool { try c.encode(v) }
        else { try c.encodeNil() }
    }
}

// MARK: - Search
struct SearchResult: Decodable, Identifiable {
    let id: String
    let type: String
    let title: String
    let subtitle: String
    let url: String
}

struct SearchResponse: Decodable {
    let query: String
    let results: [SearchResult]
}

// MARK: - API Error
struct APIErrorResponse: Decodable {
    let message: String
}

// MARK: - Empty Response (for 204 No Content)
struct EmptyResponse: Decodable {}
