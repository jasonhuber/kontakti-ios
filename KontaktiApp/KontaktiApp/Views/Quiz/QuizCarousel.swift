import SwiftUI

/// Horizontal-scrolling carousel of `QuizCard`s for the Today screen. Sits
/// above the reach-out items and disappears entirely once the queue is empty.
struct QuizCarousel: View {
    @ObservedObject var vm: TodayViewModel
    /// Navigate to the dedicated full-screen quiz session.
    let onStartSession: () -> Void

    var body: some View {
        if vm.quiz.isEmpty { EmptyView() } else { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Help me learn your network")
                        .font(.headline)
                    Text("\(vm.quiz.count) quick question\(vm.quiz.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if vm.quiz.count >= 5 {
                    Button(action: onStartSession) {
                        Text("Start daily quiz")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color(red: 0.31, green: 0.27, blue: 0.90))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.quiz) { prompt in
                        QuizCard(
                            prompt: prompt,
                            onAnswer: { answer, note in
                                Task {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        // Trigger SwiftUI to animate the card out
                                    }
                                    await vm.answerPrompt(prompt, answer: answer, note: note)
                                }
                            },
                            onSkip: { permanent in
                                Task {
                                    await vm.skipPrompt(prompt, permanent: permanent)
                                }
                            }
                        )
                        .frame(width: 320)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.quiz)
            }
        }
        .padding(.bottom, 4)
    }
}
