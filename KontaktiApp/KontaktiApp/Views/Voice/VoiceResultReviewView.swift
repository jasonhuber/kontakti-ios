import SwiftUI

/// Reviews the AI-extracted result of a voice memo: transcript, summary,
/// discussions, tasks, and person references. v1 is read-only-with-edits;
/// "Discard" is a stub TODO.
struct VoiceResultReviewView: View {
    let result: VoiceCaptureResult
    let onDone: () -> Void
    let onDiscard: () -> Void

    @State private var editingTranscript = false
    @State private var transcript: String
    @State private var summary: String
    @State private var discussions: [EditableDiscussion]
    @State private var tasks: [EditableTask]

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    init(result: VoiceCaptureResult, onDone: @escaping () -> Void, onDiscard: @escaping () -> Void) {
        self.result = result
        self.onDone = onDone
        self.onDiscard = onDiscard
        _transcript = State(initialValue: result.transcript)
        _summary = State(initialValue: result.summary)
        _discussions = State(initialValue: result.discussions.map { EditableDiscussion(from: $0) })
        _tasks = State(initialValue: result.tasks.map { EditableTask(from: $0) })
    }

    var body: some View {
        Form {
            Section {
                Text(summary)
                    .font(.body)
            } header: {
                Text("Summary")
            }

            Section {
                Toggle("Edit transcript", isOn: $editingTranscript)
                if editingTranscript {
                    TextEditor(text: $transcript)
                        .frame(minHeight: 140)
                } else {
                    Text(transcript)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Transcript")
            }

            if !discussions.isEmpty {
                Section {
                    ForEach($discussions) { $d in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(d.typeEmoji)
                                Text(d.type.capitalized)
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            // iOS 18: vertical-axis TextFields can render typed
                            // text in non-adaptive black. Force adaptive primary
                            // and give it a tertiary background for contrast.
                            TextField("Summary", text: $d.summary, axis: .vertical)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )
                            if !d.participantNames.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(d.participantNames, id: \.self) { name in
                                            Text(name)
                                                .font(.caption)
                                                .padding(.horizontal, 8).padding(.vertical, 3)
                                                .background(indigo.opacity(0.12))
                                                .foregroundColor(indigo)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Discussions (\(discussions.count))")
                }
            }

            if !tasks.isEmpty {
                Section {
                    ForEach($tasks) { $t in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Task", text: $t.title)
                                .font(.body)
                            HStack {
                                Menu {
                                    ForEach(TaskPriority.allCases, id: \.self) { p in
                                        Button(p.rawValue.capitalized) { t.priority = p }
                                    }
                                } label: {
                                    Label(t.priority.rawValue.capitalized, systemImage: "flag")
                                        .font(.caption)
                                }
                                Spacer()
                                if let due = t.dueAt {
                                    Text(due.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Tasks (\(tasks.count))")
                }
            }

            if !result.personRefs.isEmpty {
                Section {
                    ForEach(result.personRefs) { ref in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ref.nameHint)
                                    .font(.body)
                                Text(ref.action)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Create new person?") {
                                // TODO: hook to CreatePersonView
                            }
                            .font(.caption)
                            .foregroundColor(indigo)
                        }
                    }
                } header: {
                    Text("Mentioned people")
                }
            }

            Section {
                Button(role: .destructive) {
                    // TODO: call DELETE on each created discussion/task once
                    // the backend supports a `discard` flow.
                    onDiscard()
                } label: {
                    Label("Discard everything", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    invalidateCaches()
                    onDone()
                }
                .fontWeight(.semibold)
            }
        }
    }

    /// Surface to other parts of the app that data should refresh.
    /// We post a notification that view models can listen for.
    private func invalidateCaches() {
        NotificationCenter.default.post(name: .kontaktiVoiceCaptureCommitted, object: nil)
    }
}

// MARK: - Editable wrappers

private struct EditableDiscussion: Identifiable {
    let id: String
    var summary: String
    var type: String
    var participantNames: [String]

    var typeEmoji: String {
        DiscussionType(rawValue: type)?.emoji ?? "💡"
    }

    init(from d: Discussion) {
        self.id = d.id
        self.summary = d.summary ?? d.title
        self.type = d.type.rawValue
        self.participantNames = (d.participants ?? []).map { $0.fullName }
    }
}

private struct EditableTask: Identifiable {
    let id: String
    var title: String
    var priority: TaskPriority
    var dueAt: Date?

    init(from t: KontaktiTask) {
        self.id = t.id
        self.title = t.title
        self.priority = t.priority
        self.dueAt = t.dueAt
    }
}

extension TaskPriority: CaseIterable {
    public static var allCases: [TaskPriority] { [.low, .medium, .high, .urgent] }
}

extension Notification.Name {
    static let kontaktiVoiceCaptureCommitted = Notification.Name("kontakti.voiceCaptureCommitted")
    static let kontaktiPresentVoiceRecorder  = Notification.Name("kontakti.presentVoiceRecorder")
    /// Posted when a push notification (or other signal) implies that the
    /// Today inbox payload changed and the widget snapshot should refresh.
    static let kontaktiTodayShouldRefresh    = Notification.Name("kontakti.todayShouldRefresh")
}
