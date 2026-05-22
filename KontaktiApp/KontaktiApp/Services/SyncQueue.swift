import Foundation

// MARK: - Pending Mutation

/// A mutation that was attempted while offline and needs to be replayed when connectivity returns.
enum PendingMutation: Codable {
    case createPerson(ImportCandidate)
    case logDiscussion(CreateDiscussionRequest)
    case completeTask(taskId: String)

    // MARK: Codable plumbing

    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    private enum MutationType: String, Codable {
        case createPerson, logDiscussion, completeTask
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .createPerson(let candidate):
            try container.encode(MutationType.createPerson, forKey: .type)
            try container.encode(candidate, forKey: .payload)
        case .logDiscussion(let req):
            try container.encode(MutationType.logDiscussion, forKey: .type)
            try container.encode(req, forKey: .payload)
        case .completeTask(let id):
            try container.encode(MutationType.completeTask, forKey: .type)
            try container.encode(id, forKey: .payload)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MutationType.self, forKey: .type)
        switch type {
        case .createPerson:
            let candidate = try container.decode(ImportCandidate.self, forKey: .payload)
            self = .createPerson(candidate)
        case .logDiscussion:
            let req = try container.decode(CreateDiscussionRequest.self, forKey: .payload)
            self = .logDiscussion(req)
        case .completeTask:
            let id = try container.decode(String.self, forKey: .payload)
            self = .completeTask(taskId: id)
        }
    }
}

// MARK: - SyncQueue

/// An actor that persists pending mutations to disk and flushes them when connectivity returns.
actor SyncQueue {
    static let shared = SyncQueue()

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("kontakti_sync_queue.json")
    }()

    private var queue: [PendingMutation] = []
    private let api = APIClient.shared

    private init() {
        queue = (try? load()) ?? []
    }

    // MARK: - Enqueue

    func enqueue(_ mutation: PendingMutation) {
        queue.append(mutation)
        try? persist()
    }

    // MARK: - Flush

    /// Attempt to replay all queued mutations against the API. Removes successful ones.
    func flush() async {
        var remaining: [PendingMutation] = []
        for mutation in queue {
            do {
                try await replay(mutation)
            } catch {
                // Keep failed mutations in the queue to retry next time
                remaining.append(mutation)
            }
        }
        queue = remaining
        try? persist()
    }

    var pendingCount: Int { queue.count }

    // MARK: - Private

    private func replay(_ mutation: PendingMutation) async throws {
        switch mutation {
        case .createPerson(let candidate):
            let req = BulkImportRequest(contacts: [candidate])
            try await api.importContacts(req)
        case .logDiscussion(let req):
            _ = try await api.createDiscussion(req)
        case .completeTask(let id):
            _ = try await api.completeTask(id)
        }
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(queue)
        try data.write(to: fileURL, options: .atomic)
    }

    private func load() throws -> [PendingMutation] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([PendingMutation].self, from: data)
    }
}
