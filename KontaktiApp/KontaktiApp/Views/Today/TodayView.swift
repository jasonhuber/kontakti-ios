import SwiftUI

struct TodayView: View {
    @StateObject var vm: TodayViewModel
    @State private var draftingItem: TodayItem?
    @State private var showingVoice = false
    @State private var showingQuizSession = false

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    init(vm: TodayViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            content
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingVoice = true
                } label: {
                    Image(systemName: "mic.fill")
                }
                .tint(indigo)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await vm.refreshBatch() }
                } label: {
                    if vm.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .tint(indigo)
                .disabled(vm.isRefreshing)
            }
        }
        .sheet(isPresented: $showingVoice) {
            VoiceRecordingView()
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(item: $draftingItem) { item in
            DraftMessageSheet(item: item, vm: vm)
        }
        .sheet(isPresented: $showingQuizSession) {
            QuizSessionView(vm: vm)
        }
        .overlay(alignment: .bottom) {
            if let toast = vm.toast {
                Text(toast)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { vm.toast = nil }
                    }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.items.isEmpty && vm.quiz.isEmpty {
            ProgressView()
        } else if vm.items.isEmpty && vm.quiz.isEmpty {
            EmptyStateView(
                icon: "checkmark.seal",
                title: "You're caught up",
                subtitle: "Nothing to reach out to today."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text(Date().formatted(date: .complete, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    // Daily contact quiz — sits above the reach-out list and
                    // disappears entirely once the queue is empty.
                    QuizCarousel(vm: vm) {
                        showingQuizSession = true
                    }

                    ForEach(vm.items) { item in
                        TodayItemCard(
                            item: item,
                            onDraft: { draftingItem = item },
                            onSnooze: { Task { await vm.snooze(item) } },
                            onSkip: { Task { await vm.skip(item) } }
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - TodayItemCard

private struct TodayItemCard: View {
    let item: TodayItem
    let onDraft: () -> Void
    let onSnooze: () -> Void
    let onSkip: () -> Void

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        NavigationLink(value: item.person) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    AvatarView(name: item.person.fullName, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if item.kind == .birthday {
                                Image(systemName: "birthday.cake.fill")
                                    .foregroundColor(.pink)
                            }
                            Text(item.person.fullName)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Text(item.reason)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                        Text(item.kind.label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(accentColor.opacity(0.12))
                            .foregroundColor(accentColor)
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                    Spacer()
                    if let urlStr = item.signalImageUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color(.tertiarySystemFill)
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                HStack(spacing: 8) {
                    Button(action: onDraft) {
                        Label("Draft", systemImage: "square.and.pencil")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(item.person.doNotContact ? Color(.systemGray3) : indigo)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(item.person.doNotContact)
                    .accessibilityHint(item.person.doNotContact ? "Do not contact — drafts disabled" : "")

                    if item.person.doNotContact {
                        Label("Do not contact", systemImage: "nosign")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }

                    Button(action: onSnooze) {
                        Label("Snooze", systemImage: "moon.zzz")
                            .font(.footnote)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onSkip) {
                        Label("Skip", systemImage: "xmark")
                            .font(.footnote)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private var accentColor: Color {
        switch item.kind {
        case .birthday: return .pink
        case .cadenceOverdue: return .orange
        case .followUpDue: return indigo
        case .jobChange: return .blue
        case .socialSignal: return .purple
        case .anniversaryMet: return .yellow
        case .unknown: return .gray
        }
    }
}

#Preview {
    NavigationStack { TodayView(vm: TodayViewModel()) }
}
