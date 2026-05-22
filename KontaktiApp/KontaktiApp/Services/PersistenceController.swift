import Foundation
import SwiftData

/// Sets up the SwiftData ModelContainer used throughout the app.
/// Access via PersistenceController.shared.container.
@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            PersonEntity.self,
            CompanyEntity.self,
            DiscussionEntity.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // In production consider a graceful fallback rather than a crash,
            // but a corrupt store on first launch should surface loudly.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// A preview container backed by in-memory storage — useful for SwiftUI previews.
    static var preview: ModelContainer = {
        let schema = Schema([PersonEntity.self, CompanyEntity.self, DiscussionEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
