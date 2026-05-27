import AppIntents
import Foundation

/// Siri Shortcut entry point: "Hey Siri, log Kontakti note."
///
/// Opens the app and asks the foreground to present the voice recorder
/// modal by posting `.kontaktiPresentVoiceRecorder`. The root view observes
/// this notification and presents the sheet.
@available(iOS 16.0, *)
struct LogVoiceMemoIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Kontakti note"
    static var description = IntentDescription(
        "Records a voice memo and turns it into a Kontakti discussion or task."
    )

    /// Bring the app to the foreground when the intent runs (required for
    /// AVAudioRecorder + microphone permission UX).
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .kontaktiPresentVoiceRecorder, object: nil)
        return .result()
    }
}
