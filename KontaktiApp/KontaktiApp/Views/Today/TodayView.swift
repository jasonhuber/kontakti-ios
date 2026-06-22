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
        let hasContent = !vm.items.isEmpty || !vm.quiz.isEmpty || !vm.suggestions.isEmpty
        if vm.isLoading && !hasContent {
            ProgressView()
        } else if !hasContent {
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

                    // "In the mood to reach out?" — contact schedule suggestions
                    if !vm.suggestions.isEmpty {
                        ReachOutSuggestionsPanel(vm: vm)
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

// MARK: - Reach-out suggestions panel

private struct ReachOutSuggestionsPanel: View {
    @ObservedObject var vm: TodayViewModel
    @State private var reachingOut: ReachOutSuggestion?

    private let green = Color(red: 0.13, green: 0.65, blue: 0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(green)
                    .font(.footnote)
                Text("In the mood to reach out?")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(vm.suggestions.count) due")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            ForEach(vm.suggestions) { s in
                SuggestionRow(suggestion: s, vm: vm) { reachingOut = s }
            }
        }
        .padding(.top, 4)
        .sheet(item: $reachingOut) { s in
            LogReachOutSheet(suggestion: s, vm: vm)
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: ReachOutSuggestion
    @ObservedObject var vm: TodayViewModel
    let onOpen: () -> Void

    private let green = Color(red: 0.13, green: 0.65, blue: 0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tap the contact to open the reach-out sheet (see how to contact them + log it).
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    AvatarView(name: suggestion.name, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        if let why = suggestion.why, !why.isEmpty {
                            Text(why)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        } else {
                            Text(suggestion.lastContact + (suggestion.company.map { " · \($0)" } ?? ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 14) {
                Button(action: onOpen) {
                    Label("Reach out", systemImage: "paperplane.fill")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button("Done") {
                    Task { await vm.completeSuggestion(suggestion) }
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(green)

                Button("Later") {
                    Task { await vm.snoozeSuggestion(suggestion) }
                }
                .font(.footnote)
                .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Reach-out logging sheet
//
// Opened by tapping a suggestion or its "Reach out" button. Shows how to contact
// the person (tappable call/text/email/social links) so you don't have to go
// hunting, then lets you record which channel you used + an optional note. Saving
// posts to /people/{id}/log-contact, which also marks the schedule item done.

private struct LogReachOutSheet: View {
    let suggestion: ReachOutSuggestion
    @ObservedObject var vm: TodayViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var channel: String = ""
    @State private var note: String = ""
    @State private var saving = false

    private let green = Color(red: 0.13, green: 0.65, blue: 0.45)

    // Matches the backend log-contact `via` enum.
    private let channels: [(value: String, label: String, icon: String)] = [
        ("phone", "Call", "phone.fill"),
        ("sms", "Text", "message.fill"),
        ("imessage", "iMessage", "message.fill"),
        ("whatsapp", "WhatsApp", "message.fill"),
        ("email", "Email", "envelope.fill"),
        ("instagram", "Instagram", "camera.fill"),
        ("facebook", "Facebook", "person.2.fill"),
        ("in_person", "In person", "figure.wave"),
        ("other", "Other", "ellipsis"),
    ]

    private var firstName: String { suggestion.personFirstName ?? suggestion.name }

    var body: some View {
        NavigationStack {
            Form {
                Section("How to reach \(firstName)") {
                    let methods = availableMethods
                    if methods.isEmpty {
                        Text("No saved phone, email, or socials for this person.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(methods, id: \.label) { m in
                            Button {
                                if channel.isEmpty { channel = m.channel }
                                if let url = m.url { openURL(url) }
                            } label: {
                                HStack {
                                    Label(m.value, systemImage: m.icon)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if m.url != nil {
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("How did you reach out?") {
                    Picker("Channel", selection: $channel) {
                        Text("Select…").tag("")
                        ForEach(channels, id: \.value) { c in
                            Label(c.label, systemImage: c.icon).tag(c.value)
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("What did you talk about?", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Reach out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            saving = true
                            let ok = await vm.logReachOut(
                                suggestion: suggestion,
                                via: channel.isEmpty ? "other" : channel,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
                            )
                            saving = false
                            if ok { dismiss() }
                        }
                    } label: {
                        if saving { ProgressView() } else { Text("Log").bold() }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    private struct Method {
        let label: String
        let value: String
        let icon: String
        let url: URL?
        let channel: String
    }

    private var availableMethods: [Method] {
        var out: [Method] = []
        if let p = suggestion.personPhone, !p.isEmpty {
            let digits = p.filter { $0.isNumber || $0 == "+" }
            out.append(Method(label: "Call", value: p, icon: "phone.fill", url: URL(string: "tel:\(digits)"), channel: "phone"))
            out.append(Method(label: "Text", value: p, icon: "message.fill", url: URL(string: "sms:\(digits)"), channel: "sms"))
        }
        if let e = suggestion.personEmail, !e.isEmpty {
            out.append(Method(label: "Email", value: e, icon: "envelope.fill", url: URL(string: "mailto:\(e)"), channel: "email"))
        }
        if let w = suggestion.personWhatsapp, !w.isEmpty {
            let digits = w.filter { $0.isNumber }
            out.append(Method(label: "WhatsApp", value: w, icon: "message.fill", url: URL(string: "https://wa.me/\(digits)"), channel: "whatsapp"))
        }
        if let i = suggestion.personInstagram, !i.isEmpty {
            let handle = i.hasPrefix("@") ? String(i.dropFirst()) : i
            out.append(Method(label: "Instagram", value: "@\(handle)", icon: "camera.fill", url: URL(string: "https://instagram.com/\(handle)"), channel: "instagram"))
        }
        if let f = suggestion.personFacebook, !f.isEmpty {
            let url = f.hasPrefix("http") ? f : "https://\(f)"
            out.append(Method(label: "Facebook", value: f, icon: "person.2.fill", url: URL(string: url), channel: "facebook"))
        }
        return out
    }
}

#Preview {
    NavigationStack { TodayView(vm: TodayViewModel()) }
}
