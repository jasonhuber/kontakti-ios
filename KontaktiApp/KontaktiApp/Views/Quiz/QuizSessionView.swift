import SwiftUI

/// Full-screen one-card-at-a-time quiz flow over the day's five prompts.
/// Supports back/forward navigation, skip, and "don't ask about this person
/// again". Backed by the shared `TodayViewModel` so progress is reflected
/// on the Today screen the moment the user dismisses this sheet.
struct QuizSessionView: View {
    @ObservedObject var vm: TodayViewModel
    @Environment(\.dismiss) private var dismiss

    /// Local snapshot of the queue we entered with. We don't mutate the
    /// VM's queue until each answer/skip lands so back/forward works.
    @State private var queue: [ContactPrompt] = []
    @State private var index: Int = 0
    @State private var answered: Set<String> = []

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                if queue.isEmpty {
                    Spacer()
                    Text("All done — thanks!")
                        .font(.title2.weight(.semibold))
                    Text("You've worked through today's questions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(indigo)
                        .padding(.bottom, 24)
                } else {
                    Spacer(minLength: 12)
                    TabView(selection: $index) {
                        ForEach(Array(queue.enumerated()), id: \.element.id) { idx, prompt in
                            QuizCard(
                                prompt: prompt,
                                onAnswer: { answer, note in
                                    Task { await handleAnswer(prompt, answer: answer, note: note) }
                                },
                                onSkip: { permanent in
                                    Task { await handleSkip(prompt, permanent: permanent) }
                                },
                                showsPermanentSkip: true
                            )
                            .padding(.horizontal, 16)
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    navigationFooter
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Daily quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            queue = vm.quiz
            index = 0
        }
    }

    // MARK: - Subviews

    private var progressHeader: some View {
        VStack(spacing: 6) {
            ProgressView(value: progressValue)
                .tint(indigo)
            Text(progressLabel)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var navigationFooter: some View {
        HStack {
            Button {
                if index > 0 {
                    withAnimation { index -= 1 }
                }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .disabled(index == 0)

            Spacer()

            Button {
                advance()
            } label: {
                Label(index >= queue.count - 1 ? "Finish" : "Next",
                      systemImage: "chevron.right")
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Computed

    private var progressValue: Double {
        guard !queue.isEmpty else { return 1 }
        return Double(answered.count) / Double(queue.count)
    }

    private var progressLabel: String {
        guard !queue.isEmpty else { return "" }
        return "Card \(min(index + 1, queue.count)) of \(queue.count) · \(answered.count) answered"
    }

    // MARK: - Actions

    private func handleAnswer(_ prompt: ContactPrompt, answer: String, note: String? = nil) async {
        let ok = await vm.answerPrompt(prompt, answer: answer, note: note)
        if ok {
            answered.insert(prompt.id)
            advance()
        }
    }

    private func handleSkip(_ prompt: ContactPrompt, permanent: Bool) async {
        await vm.skipPrompt(prompt, permanent: permanent)
        answered.insert(prompt.id)
        advance()
    }

    private func advance() {
        if index >= queue.count - 1 {
            dismiss()
        } else {
            withAnimation { index += 1 }
        }
    }
}
