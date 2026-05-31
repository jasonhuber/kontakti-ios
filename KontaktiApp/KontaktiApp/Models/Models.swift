import Foundation

// MARK: - Auth
struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct GoogleLoginRequest: Encodable {
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}

struct RegisterRequest: Encodable {
    let name: String
    let username: String
    let email: String
    let password: String
    let passwordConfirmation: String

    enum CodingKeys: String, CodingKey {
        case name, username, email, password
        case passwordConfirmation = "password_confirmation"
    }
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
    let onboardedAt: Date?

    var hasCompletedOnboarding: Bool {
        onboardedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case username
        case onboardedAt = "onboarded_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }

        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        onboardedAt = try container.decodeIfPresent(Date.self, forKey: .onboardedAt)
    }
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

struct PersonEmail: Codable, Identifiable, Hashable {
    let id: String
    let value: String
    let label: String
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case value
        case label
        case isPrimary = "is_primary"
    }

    init(id: String, value: String, label: String, isPrimary: Bool) {
        self.id = id
        self.value = value
        self.label = label
        self.isPrimary = isPrimary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id may be int or string from backend; tolerate both
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        value = try c.decode(String.self, forKey: .value)
        label = (try? c.decode(String.self, forKey: .label)) ?? "other"
        isPrimary = (try? c.decode(Bool.self, forKey: .isPrimary)) ?? false
    }
}

struct PersonPhone: Codable, Identifiable, Hashable {
    let id: String
    let value: String
    let label: String
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case value
        case label
        case isPrimary = "is_primary"
    }

    init(id: String, value: String, label: String, isPrimary: Bool) {
        self.id = id
        self.value = value
        self.label = label
        self.isPrimary = isPrimary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        value = try c.decode(String.self, forKey: .value)
        label = (try? c.decode(String.self, forKey: .label)) ?? "other"
        isPrimary = (try? c.decode(Bool.self, forKey: .isPrimary)) ?? false
    }
}

struct Address: Codable, Identifiable, Hashable {
    var id: String { "\(label)|\(street)|\(city)|\(region)|\(postalCode)|\(country)" }
    var label: String
    var street: String
    var city: String
    var region: String
    var postalCode: String
    var country: String

    enum CodingKeys: String, CodingKey {
        case label
        case street
        case city
        case region
        case postalCode = "postal_code"
        case country
    }

    init(label: String = "home", street: String = "", city: String = "", region: String = "", postalCode: String = "", country: String = "") {
        self.label = label
        self.street = street
        self.city = city
        self.region = region
        self.postalCode = postalCode
        self.country = country
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = (try? c.decode(String.self, forKey: .label)) ?? "home"
        street = (try? c.decode(String.self, forKey: .street)) ?? ""
        city = (try? c.decode(String.self, forKey: .city)) ?? ""
        region = (try? c.decode(String.self, forKey: .region)) ?? ""
        postalCode = (try? c.decode(String.self, forKey: .postalCode)) ?? ""
        country = (try? c.decode(String.self, forKey: .country)) ?? ""
    }

    var isEmpty: Bool {
        street.isEmpty && city.isEmpty && region.isEmpty && postalCode.isEmpty && country.isEmpty
    }

    var singleLine: String {
        [street, city, region, postalCode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

struct PersonPhoto: Codable, Identifiable, Hashable {
    let id: String
    let personId: String
    let url: String
    let source: String
    let isPrimary: Bool
    let sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case personId = "person_id"
        case url
        case source
        case isPrimary = "is_primary"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        personId: String,
        url: String,
        source: String = "manual_upload",
        isPrimary: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.personId = personId
        self.url = url
        self.source = source
        self.isPrimary = isPrimary
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        if let s = try? c.decode(String.self, forKey: .personId) {
            personId = s
        } else if let i = try? c.decode(Int.self, forKey: .personId) {
            personId = String(i)
        } else {
            personId = ""
        }
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        source = (try? c.decodeIfPresent(String.self, forKey: .source)) ?? "manual_upload"
        isPrimary = (try? c.decodeIfPresent(Bool.self, forKey: .isPrimary)) ?? false
        sortOrder = (try? c.decodeIfPresent(Int.self, forKey: .sortOrder)) ?? 0
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try? c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct PersonURL: Codable, Identifiable, Hashable {
    var id: String { "\(label)|\(value)" }
    var label: String
    var value: String

    init(label: String = "website", value: String = "") {
        self.label = label
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = (try? c.decode(String.self, forKey: .label)) ?? "other"
        value = (try? c.decode(String.self, forKey: .value)) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case label, value
    }
}

struct Person: Decodable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let fullName: String
    let nickname: String?
    let email: String?
    let phone: String?
    let emails: [PersonEmail]
    let phones: [PersonPhone]
    let linkedinUrl: String?
    let avatarUrl: String?
    let photos: [PersonPhoto]
    let companyId: String?
    let company: Company?
    let title: String?
    let jobDepartment: String?
    let birthday: Date?
    let addresses: [Address]
    let urls: [PersonURL]
    let relationshipStrength: RelationshipStrength
    let lastContactedAt: Date?
    let nextFollowupAt: Date?
    let contactCadence: String?
    let contactOnBirthday: Bool?
    let contactOnHolidays: Bool?
    let notes: String?
    let deviceNote: String?
    let tags: [Tag]
    let discussionsCount: Int?
    let dealsCount: Int?
    let tasksCount: Int?
    let createdAt: Date
    let updatedAt: Date

    // Relationship-engine additions
    let instagramHandle: String?
    let facebookUrl: String?
    let twitterXHandle: String?
    let tiktokHandle: String?
    let whatsappPhone: String?
    let previousEmployers: [String]
    let city: String?
    let region: String?
    let country: String?
    let howWeMet: String?
    let introducedById: String?
    let linkedinLastScrapedAt: Date?

    // Do Not Contact
    let doNotContact: Bool
    let doNotContactReason: String?

    // Preferred contact method (e.g. "facebook" when that's the only way to reach them)
    let preferredContactVia: String?

    // Review queue
    let needsReview: Bool
    let reviewedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case nickname
        case email
        case phone
        case emails
        case phones
        case linkedinUrl = "linkedin_url"
        case avatarUrl = "avatar_url"
        case photos
        case companyId = "company_id"
        case company
        case title
        case jobDepartment = "job_department"
        case birthday
        case addresses
        case urls
        case relationshipStrength = "relationship_strength"
        case lastContactedAt = "last_contacted_at"
        case nextFollowupAt = "next_followup_at"
        case contactCadence = "contact_cadence"
        case contactOnBirthday = "contact_on_birthday"
        case contactOnHolidays = "contact_on_holidays"
        case notes
        case deviceNote = "device_note"
        case tags
        case discussionsCount = "discussions_count"
        case dealsCount = "deals_count"
        case tasksCount = "tasks_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case instagramHandle = "instagram_handle"
        case facebookUrl = "facebook_url"
        case twitterXHandle = "twitter_x_handle"
        case tiktokHandle = "tiktok_handle"
        case whatsappPhone = "whatsapp_phone"
        case previousEmployers = "previous_employers"
        case city
        case region
        case country
        case howWeMet = "how_we_met"
        case introducedById = "introduced_by_id"
        case linkedinLastScrapedAt = "linkedin_last_scraped_at"
        case doNotContact = "do_not_contact"
        case doNotContactReason = "do_not_contact_reason"
        case preferredContactVia = "preferred_contact_via"
        case needsReview = "needs_review"
        case reviewedAt = "reviewed_at"
    }

    init(
        id: String,
        firstName: String,
        lastName: String,
        fullName: String,
        nickname: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        emails: [PersonEmail] = [],
        phones: [PersonPhone] = [],
        linkedinUrl: String? = nil,
        avatarUrl: String? = nil,
        photos: [PersonPhoto] = [],
        companyId: String? = nil,
        company: Company? = nil,
        title: String? = nil,
        jobDepartment: String? = nil,
        birthday: Date? = nil,
        addresses: [Address] = [],
        urls: [PersonURL] = [],
        relationshipStrength: RelationshipStrength = .cold,
        lastContactedAt: Date? = nil,
        nextFollowupAt: Date? = nil,
        contactCadence: String? = nil,
        contactOnBirthday: Bool? = nil,
        contactOnHolidays: Bool? = nil,
        notes: String? = nil,
        deviceNote: String? = nil,
        tags: [Tag] = [],
        discussionsCount: Int? = nil,
        dealsCount: Int? = nil,
        tasksCount: Int? = nil,
        createdAt: Date,
        updatedAt: Date,
        instagramHandle: String? = nil,
        facebookUrl: String? = nil,
        twitterXHandle: String? = nil,
        tiktokHandle: String? = nil,
        whatsappPhone: String? = nil,
        previousEmployers: [String] = [],
        city: String? = nil,
        region: String? = nil,
        country: String? = nil,
        howWeMet: String? = nil,
        introducedById: String? = nil,
        linkedinLastScrapedAt: Date? = nil,
        doNotContact: Bool = false,
        doNotContactReason: String? = nil,
        preferredContactVia: String? = nil,
        needsReview: Bool = false,
        reviewedAt: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.nickname = nickname
        self.email = email
        self.phone = phone
        self.emails = emails
        self.phones = phones
        self.linkedinUrl = linkedinUrl
        self.avatarUrl = avatarUrl
        self.photos = photos
        self.companyId = companyId
        self.company = company
        self.title = title
        self.jobDepartment = jobDepartment
        self.birthday = birthday
        self.addresses = addresses
        self.urls = urls
        self.relationshipStrength = relationshipStrength
        self.lastContactedAt = lastContactedAt
        self.nextFollowupAt = nextFollowupAt
        self.contactCadence = contactCadence
        self.contactOnBirthday = contactOnBirthday
        self.contactOnHolidays = contactOnHolidays
        self.notes = notes
        self.deviceNote = deviceNote
        self.tags = tags
        self.discussionsCount = discussionsCount
        self.dealsCount = dealsCount
        self.tasksCount = tasksCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.instagramHandle = instagramHandle
        self.facebookUrl = facebookUrl
        self.twitterXHandle = twitterXHandle
        self.tiktokHandle = tiktokHandle
        self.whatsappPhone = whatsappPhone
        self.previousEmployers = previousEmployers
        self.city = city
        self.region = region
        self.country = country
        self.howWeMet = howWeMet
        self.introducedById = introducedById
        self.linkedinLastScrapedAt = linkedinLastScrapedAt
        self.doNotContact = doNotContact
        self.doNotContactReason = doNotContactReason
        self.preferredContactVia = preferredContactVia
        self.needsReview = needsReview
        self.reviewedAt = reviewedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        firstName = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        lastName = (try? c.decode(String.self, forKey: .lastName)) ?? ""
        fullName = (try? c.decode(String.self, forKey: .fullName)) ?? ""
        nickname = try? c.decode(String.self, forKey: .nickname)
        email = try? c.decode(String.self, forKey: .email)
        phone = try? c.decode(String.self, forKey: .phone)
        emails = (try? c.decode([PersonEmail].self, forKey: .emails)) ?? []
        phones = (try? c.decode([PersonPhone].self, forKey: .phones)) ?? []
        linkedinUrl = try? c.decode(String.self, forKey: .linkedinUrl)
        avatarUrl = try? c.decode(String.self, forKey: .avatarUrl)
        photos = (try? c.decodeIfPresent([PersonPhoto].self, forKey: .photos)) ?? []
        companyId = try? c.decode(String.self, forKey: .companyId)
        company = try? c.decode(Company.self, forKey: .company)
        title = try? c.decode(String.self, forKey: .title)
        jobDepartment = try? c.decode(String.self, forKey: .jobDepartment)

        // birthday may be "YYYY-MM-DD"
        if let s = try? c.decode(String.self, forKey: .birthday), !s.isEmpty {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .iso8601)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyy-MM-dd"
            birthday = f.date(from: s)
        } else {
            birthday = try? c.decode(Date.self, forKey: .birthday)
        }

        addresses = (try? c.decode([Address].self, forKey: .addresses)) ?? []
        urls = (try? c.decode([PersonURL].self, forKey: .urls)) ?? []
        relationshipStrength = (try? c.decode(RelationshipStrength.self, forKey: .relationshipStrength)) ?? .cold
        lastContactedAt = try? c.decode(Date.self, forKey: .lastContactedAt)
        nextFollowupAt = try? c.decode(Date.self, forKey: .nextFollowupAt)
        contactCadence = try? c.decode(String.self, forKey: .contactCadence)
        contactOnBirthday = try? c.decodeIfPresent(Bool.self, forKey: .contactOnBirthday)
        contactOnHolidays = try? c.decodeIfPresent(Bool.self, forKey: .contactOnHolidays)
        notes = try? c.decode(String.self, forKey: .notes)
        deviceNote = try? c.decode(String.self, forKey: .deviceNote)
        tags = (try? c.decode([Tag].self, forKey: .tags)) ?? []
        discussionsCount = try? c.decode(Int.self, forKey: .discussionsCount)
        dealsCount = try? c.decode(Int.self, forKey: .dealsCount)
        tasksCount = try? c.decode(Int.self, forKey: .tasksCount)
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? Date()

        instagramHandle = try? c.decode(String.self, forKey: .instagramHandle)
        facebookUrl = try? c.decode(String.self, forKey: .facebookUrl)
        twitterXHandle = try? c.decode(String.self, forKey: .twitterXHandle)
        tiktokHandle = try? c.decode(String.self, forKey: .tiktokHandle)
        whatsappPhone = try? c.decode(String.self, forKey: .whatsappPhone)
        previousEmployers = (try? c.decode([String].self, forKey: .previousEmployers)) ?? []
        city = try? c.decode(String.self, forKey: .city)
        region = try? c.decode(String.self, forKey: .region)
        country = try? c.decode(String.self, forKey: .country)
        howWeMet = try? c.decode(String.self, forKey: .howWeMet)
        introducedById = try? c.decode(String.self, forKey: .introducedById)
        linkedinLastScrapedAt = try? c.decode(Date.self, forKey: .linkedinLastScrapedAt)
        doNotContact = (try? c.decodeIfPresent(Bool.self, forKey: .doNotContact)) ?? false
        doNotContactReason = try? c.decodeIfPresent(String.self, forKey: .doNotContactReason)
        preferredContactVia = try? c.decode(String.self, forKey: .preferredContactVia)
        needsReview = (try? c.decodeIfPresent(Bool.self, forKey: .needsReview)) ?? false
        reviewedAt = try? c.decodeIfPresent(Date.self, forKey: .reviewedAt)
    }
}

extension Person: Hashable {
    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

extension Company: Hashable {
    static func == (lhs: Company, rhs: Company) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

extension Discussion: Hashable {
    static func == (lhs: Discussion, rhs: Discussion) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CreateDiscussionRequest: Codable {
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

// MARK: - PersonPatch

/// Partial update payload for `PATCH /api/v1/people/{id}`.
///
/// Every field is optional — only non-nil fields are encoded. Use static
/// helper constructors or set properties directly via the empty `init()`.
/// `emails` / `phones` use replace-list semantics on the backend.
struct PersonPatch: Encodable {
    var firstName: String?
    var lastName: String?
    var nickname: String?
    var title: String?
    var jobDepartment: String?
    var companyId: String?
    var companyName: String?
    var email: String?
    var phone: String?
    var emails: [PersonEmailPatch]?
    var phones: [PersonPhonePatch]?
    var birthday: String?              // "YYYY-MM-DD" or "" to clear
    var addresses: [Address]?
    var urls: [PersonURL]?
    var linkedinUrl: String?
    var relationshipStrength: String?
    var nextFollowupAt: String?        // ISO 8601 or "" to clear
    var lastContactedAt: String?
    var contactCadence: String?
    var contactOnBirthday: Bool?
    var contactOnHolidays: Bool?
    var notes: String?
    var deviceNote: String?
    var tagIds: [String]?

    // Relationship-engine additions
    var instagramHandle: String?
    var facebookUrl: String?
    var twitterXHandle: String?
    var tiktokHandle: String?
    var whatsappPhone: String?
    var previousEmployers: [String]?
    var city: String?
    var region: String?
    var country: String?
    var howWeMet: String?
    var introducedById: String?

    // Do Not Contact
    var doNotContact: Bool?
    var doNotContactReason: String?

    // Preferred contact method — set to "facebook" (or nil to clear)
    var preferredContactVia: String?

    init() {}

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case nickname
        case title
        case jobDepartment = "job_department"
        case companyId = "company_id"
        case companyName = "company_name"
        case email
        case phone
        case emails
        case phones
        case birthday
        case addresses
        case urls
        case linkedinUrl = "linkedin_url"
        case relationshipStrength = "relationship_strength"
        case nextFollowupAt = "next_followup_at"
        case lastContactedAt = "last_contacted_at"
        case contactCadence = "contact_cadence"
        case contactOnBirthday = "contact_on_birthday"
        case contactOnHolidays = "contact_on_holidays"
        case notes
        case deviceNote = "device_note"
        case tagIds = "tag_ids"
        case instagramHandle = "instagram_handle"
        case facebookUrl = "facebook_url"
        case twitterXHandle = "twitter_x_handle"
        case tiktokHandle = "tiktok_handle"
        case whatsappPhone = "whatsapp_phone"
        case previousEmployers = "previous_employers"
        case city
        case region
        case country
        case howWeMet = "how_we_met"
        case introducedById = "introduced_by_id"
        case doNotContact = "do_not_contact"
        case doNotContactReason = "do_not_contact_reason"
        case preferredContactVia = "preferred_contact_via"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(firstName, forKey: .firstName)
        try c.encodeIfPresent(lastName, forKey: .lastName)
        try c.encodeIfPresent(nickname, forKey: .nickname)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(jobDepartment, forKey: .jobDepartment)
        try c.encodeIfPresent(companyId, forKey: .companyId)
        try c.encodeIfPresent(companyName, forKey: .companyName)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(phone, forKey: .phone)
        try c.encodeIfPresent(emails, forKey: .emails)
        try c.encodeIfPresent(phones, forKey: .phones)
        try c.encodeIfPresent(birthday, forKey: .birthday)
        try c.encodeIfPresent(addresses, forKey: .addresses)
        try c.encodeIfPresent(urls, forKey: .urls)
        try c.encodeIfPresent(linkedinUrl, forKey: .linkedinUrl)
        try c.encodeIfPresent(relationshipStrength, forKey: .relationshipStrength)
        try c.encodeIfPresent(nextFollowupAt, forKey: .nextFollowupAt)
        try c.encodeIfPresent(lastContactedAt, forKey: .lastContactedAt)
        try c.encodeIfPresent(contactCadence, forKey: .contactCadence)
        try c.encodeIfPresent(contactOnBirthday, forKey: .contactOnBirthday)
        try c.encodeIfPresent(contactOnHolidays, forKey: .contactOnHolidays)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(deviceNote, forKey: .deviceNote)
        try c.encodeIfPresent(tagIds, forKey: .tagIds)
        try c.encodeIfPresent(instagramHandle, forKey: .instagramHandle)
        try c.encodeIfPresent(facebookUrl, forKey: .facebookUrl)
        try c.encodeIfPresent(twitterXHandle, forKey: .twitterXHandle)
        try c.encodeIfPresent(tiktokHandle, forKey: .tiktokHandle)
        try c.encodeIfPresent(whatsappPhone, forKey: .whatsappPhone)
        try c.encodeIfPresent(previousEmployers, forKey: .previousEmployers)
        try c.encodeIfPresent(city, forKey: .city)
        try c.encodeIfPresent(region, forKey: .region)
        try c.encodeIfPresent(country, forKey: .country)
        try c.encodeIfPresent(howWeMet, forKey: .howWeMet)
        try c.encodeIfPresent(introducedById, forKey: .introducedById)
        try c.encodeIfPresent(doNotContact, forKey: .doNotContact)
        try c.encodeIfPresent(doNotContactReason, forKey: .doNotContactReason)
        try c.encodeIfPresent(preferredContactVia, forKey: .preferredContactVia)
    }
}

struct PersonEmailPatch: Encodable {
    let value: String
    let label: String
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case value
        case label
        case isPrimary = "is_primary"
    }
}

struct PersonPhonePatch: Encodable {
    let value: String
    let label: String
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case value
        case label
        case isPrimary = "is_primary"
    }
}

// MARK: - Note create/update

struct CreateNoteRequest: Encodable {
    let title: String?
    let body: String
    let notableType: String
    let notableId: String

    enum CodingKeys: String, CodingKey {
        case title
        case body
        case notableType = "notable_type"
        case notableId = "notable_id"
    }
}

struct UpdateNoteRequest: Encodable {
    let title: String?
    let body: String
}

// MARK: - Relationship Engine Models

enum TodayItemKind: String, Decodable, Hashable {
    case birthday
    case cadenceOverdue = "cadence_overdue"
    case followUpDue = "follow_up_due"
    case jobChange = "job_change"
    case socialSignal = "social_signal"
    case anniversaryMet = "anniversary_met"
    case unknown

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try? c.decode(String.self)) ?? ""
        self = TodayItemKind(rawValue: raw) ?? .unknown
    }

    var icon: String {
        switch self {
        case .birthday: return "birthday.cake"
        case .cadenceOverdue: return "clock.badge.exclamationmark"
        case .followUpDue: return "calendar.badge.clock"
        case .jobChange: return "briefcase"
        case .socialSignal: return "sparkles"
        case .anniversaryMet: return "star"
        case .unknown: return "bell"
        }
    }

    var label: String {
        switch self {
        case .birthday: return "Birthday"
        case .cadenceOverdue: return "Overdue"
        case .followUpDue: return "Follow-up"
        case .jobChange: return "Job change"
        case .socialSignal: return "Social"
        case .anniversaryMet: return "Anniversary"
        case .unknown: return "Today"
        }
    }
}

struct TodayItem: Decodable, Identifiable, Hashable {
    let id: String
    let kind: TodayItemKind
    let person: Person
    let reason: String
    let priority: Double
    let signal: [String: AnyCodable]?
    let suggestedMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case person
        case reason
        case priority
        case signal
        case suggestedMessage = "suggested_message"
    }

    var signalImageUrl: String? {
        signal?["image_url"]?.stringValue
    }

    static func == (lhs: TodayItem, rhs: TodayItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SocialActivity: Decodable, Identifiable, Hashable {
    let id: String
    let source: String          // instagram, facebook, linkedin, twitter, tiktok
    let kind: String            // post, story, job_change, etc.
    let occurredAt: Date?
    let content: String?
    let location: String?
    let imageUrl: String?
    let externalUrl: String?
    let engagement: [String: AnyCodable]?
    let acknowledgedAt: Date?
    let personId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case kind
        case occurredAt = "occurred_at"
        case content
        case location
        case imageUrl = "image_url"
        case externalUrl = "external_url"
        case engagement
        case acknowledgedAt = "acknowledged_at"
        case personId = "person_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        source = (try? c.decode(String.self, forKey: .source)) ?? "unknown"
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "post"
        occurredAt = try? c.decode(Date.self, forKey: .occurredAt)
        content = try? c.decode(String.self, forKey: .content)
        location = try? c.decode(String.self, forKey: .location)
        imageUrl = try? c.decode(String.self, forKey: .imageUrl)
        externalUrl = try? c.decode(String.self, forKey: .externalUrl)
        engagement = try? c.decode([String: AnyCodable].self, forKey: .engagement)
        acknowledgedAt = try? c.decode(Date.self, forKey: .acknowledgedAt)
        personId = try? c.decode(String.self, forKey: .personId)
    }

    static func == (lhs: SocialActivity, rhs: SocialActivity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var sourceIcon: String {
        switch source.lowercased() {
        case "instagram": return "camera"
        case "facebook": return "f.cursive.circle"
        case "linkedin": return "briefcase"
        case "twitter", "x": return "bird"
        case "tiktok": return "music.note"
        default: return "bell"
        }
    }
}

struct SocialGroup: Decodable, Identifiable, Hashable {
    let id: String
    let source: String         // facebook | whatsapp
    let externalId: String
    let name: String?
    let memberCount: Int
    let lastSyncedAt: Date?
    let members: [Person]?

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case externalId = "external_id"
        case name
        case memberCount = "member_count"
        case lastSyncedAt = "last_synced_at"
        case members
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        source = (try? c.decode(String.self, forKey: .source)) ?? "unknown"
        externalId = (try? c.decode(String.self, forKey: .externalId)) ?? ""
        name = try? c.decode(String.self, forKey: .name)
        memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        lastSyncedAt = try? c.decode(Date.self, forKey: .lastSyncedAt)
        members = try? c.decode([Person].self, forKey: .members)
    }

    static func == (lhs: SocialGroup, rhs: SocialGroup) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SocialGroupSyncResult: Decodable {
    let created: Int
    let attached: Int
    let memberCount: Int

    enum CodingKeys: String, CodingKey {
        case created
        case attached
        case memberCount = "member_count"
    }
}

struct JobDetectionResult: Decodable {
    let detected: Int
    let errors: Int
}

struct DraftMessageResponse: Decodable {
    let draft: String
}

struct LogReachOutResponse: Decodable {
    let lastContactedAt: Date?

    enum CodingKeys: String, CodingKey {
        case lastContactedAt = "last_contacted_at"
    }
}

// MARK: - Daily Contact Quiz

/// One of the five canonical questions the daily quiz cycles through.
/// Mirrors the backend `question_key` enum.
enum QuestionKey: String, Codable, Hashable, CaseIterable {
    case recognize          // "Do you recognize this person?"
    case howWeMet = "how_we_met"
    case relationshipType = "relationship_type"
    case lastRecall = "last_recall"
    case notable

    var displayLabel: String {
        switch self {
        case .recognize: return "Recognize"
        case .howWeMet: return "How we met"
        case .relationshipType: return "Relationship"
        case .lastRecall: return "Last memory"
        case .notable: return "Anything notable"
        }
    }

    /// `notable` is the only question where free-form text entry is the
    /// primary input. Others lead with chip-style suggested responses.
    var requiresFreeText: Bool { self == .notable }
}

/// A single quiz prompt returned by `/today.quiz` and answered via
/// `/quiz/{prompt}/answer` or skipped via `/quiz/{prompt}/skip`.
struct ContactPrompt: Decodable, Identifiable, Hashable {
    let id: String
    let person: Person
    let questionKey: QuestionKey
    let questionText: String
    let suggestedResponses: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case person
        case questionKey = "question_key"
        case questionText = "question_text"
        case suggestedResponses = "suggested_responses"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        person = try c.decode(Person.self, forKey: .person)
        let rawKey = (try? c.decode(String.self, forKey: .questionKey)) ?? "recognize"
        questionKey = QuestionKey(rawValue: rawKey) ?? .recognize
        questionText = (try? c.decode(String.self, forKey: .questionText)) ?? ""
        suggestedResponses = (try? c.decode([String].self, forKey: .suggestedResponses)) ?? []
    }

    static func == (lhs: ContactPrompt, rhs: ContactPrompt) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Per-person rhythm metadata returned alongside the today payload.
struct RhythmSnapshot: Codable, Hashable {
    let interactionCount: Int
    let meanIntervalDays: Double?
    let daysSinceLast: Int?
    let state: String           // e.g. "active", "fading", "dormant"
    let rhythmLabel: String

    enum CodingKeys: String, CodingKey {
        case interactionCount = "interaction_count"
        case meanIntervalDays = "mean_interval_days"
        case daysSinceLast = "days_since_last"
        case state
        case rhythmLabel = "rhythm_label"
    }
}

/// Wraps a per-person rhythm message for the Today screen.
struct RhythmInsight: Decodable, Identifiable, Hashable {
    let personId: String
    let rhythm: RhythmSnapshot
    let message: String

    var id: String { personId }

    enum CodingKeys: String, CodingKey {
        case personId = "person_id"
        case rhythm
        case message
    }
}

/// New combined shape of `GET /api/v1/today`. The legacy bare-array shape
/// is still tolerated by `APIClient.listToday()` for backward compatibility,
/// but new code should call `loadTodayWithQuiz()`.
struct TodayResponse: Decodable {
    let items: [TodayItem]
    let count: Int
    let quiz: [ContactPrompt]
    let rhythmInsights: [RhythmInsight]

    enum CodingKeys: String, CodingKey {
        case items
        case count
        case quiz
        case rhythmInsights = "rhythm_insights"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decode([TodayItem].self, forKey: .items)) ?? []
        count = (try? c.decode(Int.self, forKey: .count)) ?? items.count
        quiz = (try? c.decode([ContactPrompt].self, forKey: .quiz)) ?? []
        rhythmInsights = (try? c.decode([RhythmInsight].self, forKey: .rhythmInsights)) ?? []
    }
}

/// What the user persisted as their own answer to a quiz prompt for a
/// given person — surfaced on the PersonDetail "What you remember" section.
struct PersonRemembrance: Decodable, Identifiable, Hashable {
    let id: String
    let questionKey: QuestionKey
    let questionText: String
    let answer: String
    let answeredAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case questionKey = "question_key"
        case questionText = "question_text"
        case answer
        case answeredAt = "answered_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        let rawKey = (try? c.decode(String.self, forKey: .questionKey)) ?? "notable"
        questionKey = QuestionKey(rawValue: rawKey) ?? .notable
        questionText = (try? c.decode(String.self, forKey: .questionText)) ?? ""
        answer = (try? c.decode(String.self, forKey: .answer)) ?? ""
        answeredAt = try? c.decode(Date.self, forKey: .answeredAt)
    }
}

struct PersonResponse: Decodable {
    let person: Person
}

// MARK: - People health (Contact Review)

struct PeopleHealth: Decodable {
    let total: Int
    let buckets: [String: HealthBucket]
}

struct HealthBucket: Decodable {
    let count: Int
    let samples: [HealthSample]
}

struct HealthSample: Decodable, Identifiable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
    }

    var displayName: String {
        let f = firstName?.trimmingCharacters(in: .whitespaces) ?? ""
        let l = lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        let combined = [f, l].filter { !$0.isEmpty }.joined(separator: " ")
        if !combined.isEmpty { return combined }
        return email ?? "Unnamed contact"
    }
}
