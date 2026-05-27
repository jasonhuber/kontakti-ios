import AppIntents

/// Registers Kontakti's App Intents with the Shortcuts app and Siri.
/// Activation phrases: "Hey Siri, log Kontakti note" / "Log a Kontakti note".
@available(iOS 16.0, *)
struct KontaktiShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogVoiceMemoIntent(),
            phrases: [
                "Log a \(.applicationName) note",
                "Take a \(.applicationName) note",
                "New \(.applicationName) memo"
            ],
            shortTitle: "Log Note",
            systemImageName: "mic.fill"
        )
    }
}
