import SwiftUI

/// Reusable single-prompt card used both in the inline Today carousel and
/// the full-screen quiz session. Owns its own free-text state for `notable`.
struct QuizCard: View {
    let prompt: ContactPrompt
    /// User picked a suggested response or typed a custom answer. The optional
    /// `note` carries a free-text note saved on the person for the AI to use.
    let onAnswer: (_ answer: String, _ note: String?) -> Void
    /// User tapped Skip. The optional `permanent` flag carries the
    /// "don't ask about this person again" decision up.
    let onSkip: (_ permanent: Bool) -> Void
    /// When true, shows the "don't ask again" action. Hidden inline; shown
    /// in the dedicated session view.
    var showsPermanentSkip: Bool = false

    @State private var freeText: String = ""
    @State private var note: String = ""

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    private var trimmedNote: String? {
        let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Person identity
            HStack(spacing: 12) {
                AvatarView(name: prompt.person.fullName, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.person.fullName)
                        .font(.headline)
                    if let title = prompt.person.title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(prompt.questionKey.displayLabel)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(indigo.opacity(0.12))
                    .foregroundColor(indigo)
                    .clipShape(Capsule())
            }

            // Question
            Text(prompt.questionText)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            // Responses
            if prompt.questionKey.requiresFreeText {
                freeTextEntry
            } else {
                suggestedChips
                if !prompt.suggestedResponses.isEmpty {
                    Divider().padding(.vertical, 2)
                    freeTextEntry
                }
            }

            // Optional free-text note — saved as a real Note on the person so
            // the AI can use it later to decide how/why to reach out. Rides
            // along with whichever answer (chip or custom) the user picks.
            // Note: `.textFieldStyle(.roundedBorder)` silently breaks when
            // combined with `axis: .vertical` on iOS 18 — typed text renders
            // black-on-black in dark mode. Style the field manually instead.
            TextField(
                "Add a note (optional) — how you know them, anything to remember…",
                text: $note,
                axis: .vertical
            )
            .font(.footnote)
            .foregroundColor(.primary)
            .lineLimit(1...4)
            .padding(8)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )

            // Save note — full-width button, only shown once the user types something
            if let n = trimmedNote {
                Button {
                    onAnswer(n, nil)
                } label: {
                    Text("Save note →")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(indigo)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            // Footer actions
            HStack(spacing: 12) {
                Button("Skip") { onSkip(false) }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if showsPermanentSkip {
                    Button("Don't ask again") { onSkip(true) }
                        .buttonStyle(.plain)
                        .font(.footnote)
                        .foregroundColor(.red.opacity(0.85))
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var suggestedChips: some View {
        let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(prompt.suggestedResponses, id: \.self) { response in
                Button {
                    onAnswer(response, trimmedNote)
                } label: {
                    Text(response)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(indigo.opacity(0.10))
                        .foregroundColor(indigo)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var freeTextEntry: some View {
        HStack(spacing: 8) {
            TextField(
                prompt.questionKey == .notable ? "Something notable…" : "Other…",
                text: $freeText,
                axis: .vertical
            )
            .foregroundColor(.primary)
            .lineLimit(1...3)
            .padding(8)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
            Button {
                let trimmed = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onAnswer(trimmed, trimmedNote)
                freeText = ""
                note = ""
            } label: {
                Text("Save")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(indigo)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
