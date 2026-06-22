import SwiftUI

struct PersonDetailView: View {
    let person: Person
    @StateObject private var vm = PersonDetailViewModel()
    @State private var showEdit = false
    @State private var showVoice = false

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]

    var displayPerson: Person {
        vm.person ?? person
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    PersonAvatarOrInitials(person: displayPerson, size: 72)
                    Text(displayPerson.fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                    if let title = displayPerson.title, let company = displayPerson.company {
                        Text("\(title) · \(company.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if let title = displayPerson.title {
                        Text(title).font(.subheadline).foregroundColor(.secondary)
                    } else if let company = displayPerson.company {
                        Text(company.name).font(.subheadline).foregroundColor(.secondary)
                    }
                    StrengthBadgeView(strength: displayPerson.relationshipStrength)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)

                // Photos (read-only on the detail; editing happens in EditPersonView)
                if !displayPerson.photos.isEmpty {
                    PhotoGalleryView(personId: displayPerson.id, editable: false)
                        .padding(.bottom, 16)
                }

                // Stats row
                HStack(spacing: 0) {
                    statCell(value: displayPerson.discussionsCount ?? 0, label: "Discussions")
                    Divider().frame(height: 36)
                    statCell(value: displayPerson.tasksCount ?? 0, label: "Tasks")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Contact info
                let mergedEmails = mergeEmails(displayPerson)
                let mergedPhones = mergePhones(displayPerson)
                if !mergedEmails.isEmpty || !mergedPhones.isEmpty || displayPerson.linkedinUrl != nil {
                    GroupBox {
                        VStack(spacing: 0) {
                            ForEach(Array(mergedEmails.enumerated()), id: \.offset) { idx, email in
                                contactRow(
                                    icon: "envelope",
                                    label: email.value,
                                    chip: email.label,
                                    url: URL(string: "mailto:\(email.value)")
                                )
                                if idx < mergedEmails.count - 1 {
                                    Divider().padding(.leading, 36)
                                }
                            }
                            if !mergedEmails.isEmpty && !mergedPhones.isEmpty {
                                Divider().padding(.leading, 36)
                            }
                            ForEach(Array(mergedPhones.enumerated()), id: \.offset) { idx, phone in
                                contactRow(
                                    icon: "phone",
                                    label: phone.value,
                                    chip: phone.label,
                                    url: URL(string: "tel:\(phone.value.filter { !$0.isWhitespace })")
                                )
                                if idx < mergedPhones.count - 1 {
                                    Divider().padding(.leading, 36)
                                }
                            }
                            if (!mergedPhones.isEmpty || !mergedEmails.isEmpty) && displayPerson.linkedinUrl != nil {
                                Divider().padding(.leading, 36)
                            }
                            if let linkedin = displayPerson.linkedinUrl, let url = URL(string: linkedin) {
                                contactRow(icon: "globe", label: "LinkedIn", chip: nil, url: url)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // Social handle chips
                socialChips
                    .padding(.bottom, displayPerson.preferredContactVia == "facebook" ? 8 : 16)

                // Facebook-only banner — shown when user marked FB as the only contact method
                if displayPerson.preferredContactVia == "facebook",
                   let fbUrl = displayPerson.facebookUrl,
                   let url = URL(string: fbUrl) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "f.cursive.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Facebook is the only way to reach \(displayPerson.firstName)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("Tap to open their profile")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(14)
                        .background(Color(red: 0.23, green: 0.35, blue: 0.60))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                // Follow-up
                if let followup = displayPerson.nextFollowupAt {
                    let overdue = followup < Date()
                    GroupBox {
                        HStack {
                            Image(systemName: overdue ? "exclamationmark.circle" : "calendar")
                                .foregroundColor(overdue ? .red : indigo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Follow-up")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(followup.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundColor(overdue ? .red : .primary)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                // Quick-log: one-tap reach-out logging
                QuickLogBarView(personId: displayPerson.id)
                    .padding(.bottom, 16)

                // Do not contact
                DoNotContactPanel(person: displayPerson, vm: vm)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Apple Contacts writeback — hidden for do-not-contact people
                // and when Contacts access hasn't been granted. Section makes
                // its own decision; we always render it and let it no-op.
                AppleContactsWritebackSection(person: displayPerson)
                    .padding(.bottom, 16)

                // Tags
                if !displayPerson.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(displayPerson.tags) { tag in
                                    Text(tag.name)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(indigo.opacity(0.12))
                                        .foregroundColor(indigo)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 16)
                }

                // Activity
                activitySection
                    .padding(.bottom, 16)

                // Timeline
                if !vm.timeline.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Timeline")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        ForEach(vm.timeline) { event in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: timelineIcon(event.type))
                                    .font(.body)
                                    .foregroundColor(indigo)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(event.data.title)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            if event.id != vm.timeline.last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }

                // What you remember about them (quiz answers)
                if !vm.remembrances.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What you remember about them")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(vm.remembrances) { r in
                                HStack(alignment: .top, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.questionKey.displayLabel)
                                            .font(.caption2.bold())
                                            .foregroundColor(.secondary)
                                        Text(r.answer)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                    // TODO: wire to in-place editor for remembrance entries.
                                    Image(systemName: "pencil")
                                        .foregroundColor(.secondary)
                                        .font(.footnote)
                                }
                                .padding(.vertical, 4)
                                if r.id != vm.remembrances.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 16)
                }

                // Notes — vm.notes holds Note records (quiz, voice, manual);
                // displayPerson.notes is the legacy plain-text column. Both are shown here.
                // Previously vm.notes was loaded but never rendered — quiz notes were
                // invisible to the user even though they were saved correctly.
                let legacyNote = (displayPerson.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !vm.notes.isEmpty || !legacyNote.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        VStack(spacing: 0) {
                            ForEach(vm.notes) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.body)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteNote(note) }
                                    } label: {
                                        Label("Delete note", systemImage: "trash")
                                    }
                                }
                                if note.id != vm.notes.last?.id || !legacyNote.isEmpty {
                                    Divider().padding(.leading, 12)
                                }
                            }
                            if !legacyNote.isEmpty {
                                Text(legacyNote)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.08))
            }
        }
        .task {
            await vm.load(id: person.id)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showVoice = true
                } label: {
                    Image(systemName: "mic.fill")
                }
                .tint(indigo)
                .accessibilityLabel("Voice memo about \(displayPerson.fullName)")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
                .tint(indigo)
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: {
            // Photo edits inside the sheet mutate server state directly and
            // don't fire the onSaved callback, so refresh on every dismissal
            // to keep the cached avatar / gallery in sync.
            Task { await vm.refresh() }
        }) {
            EditPersonView(person: displayPerson) { _ in
                Task { await vm.refresh() }
            }
        }
        .sheet(isPresented: $showVoice) {
            VoiceRecordingView(
                personId: displayPerson.id,
                context: displayPerson.fullName
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .kontaktiVoiceCaptureCommitted)) { _ in
            Task { await vm.refresh() }
        }
    }

    // MARK: - Social chips

    @ViewBuilder
    private var socialChips: some View {
        let p = displayPerson
        let chips: [(String, String, URL?)] = [
            p.instagramHandle.flatMap { h in ("camera", "@\(h)", URL(string: "instagram://user?username=\(h)")) },
            p.facebookUrl.flatMap { url in ("f.cursive.circle", "Facebook", URL(string: url)) },
            p.twitterXHandle.flatMap { h in ("bird", "@\(h)", URL(string: "https://x.com/\(h)")) },
            p.tiktokHandle.flatMap { h in ("music.note", "@\(h)", URL(string: "https://www.tiktok.com/@\(h)")) },
            p.whatsappPhone.flatMap { wa in
                let cleaned = wa.filter { !$0.isWhitespace && $0 != "+" }
                return ("phone.circle", "WhatsApp", URL(string: "whatsapp://send?phone=\(cleaned)"))
            }
        ].compactMap { $0 }

        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        Button {
                            if let url = chip.2 { UIApplication.shared.open(url) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: chip.0)
                                Text(chip.1).font(.caption)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(indigo.opacity(0.12))
                            .foregroundColor(indigo)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Activity section

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Activity")
                    .font(.footnote).fontWeight(.semibold).foregroundColor(.secondary)
                Spacer()
                Button {
                    Task { await vm.refreshActivity() }
                } label: {
                    if vm.isRefreshingActivity {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise").font(.caption)
                    }
                }
                .disabled(vm.isRefreshingActivity)
            }
            .padding(.horizontal, 16)

            if vm.activity.isEmpty {
                let hasHandles = (displayPerson.instagramHandle != nil) ||
                    (displayPerson.facebookUrl != nil) ||
                    (displayPerson.twitterXHandle != nil) ||
                    (displayPerson.tiktokHandle != nil)
                GroupBox {
                    if hasHandles {
                        Text("No recent activity yet. Pull refresh to scan.")
                            .font(.subheadline).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Button {
                            showEdit = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add social handles to start tracking activity").font(.subheadline)
                                Text("Tap to edit").font(.caption).foregroundColor(indigo)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                List {
                    ForEach(vm.activity.prefix(10)) { act in
                        ActivityRow(activity: act)
                            .swipeActions(edge: .trailing) {
                                Button("Acknowledge") {
                                    Task { await vm.acknowledge(activityId: act.id) }
                                }
                                .tint(.gray)
                            }
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(min(vm.activity.count, 10)) * 76)
                .scrollDisabled(true)
            }
        }
    }

    @ViewBuilder
    private func contactRow(icon: String, label: String, chip: String?, url: URL?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(indigo)
                .frame(width: 24)
            if let url {
                Link(label, destination: url)
                    .font(.subheadline)
                    .foregroundColor(indigo)
                    .lineLimit(1)
            } else {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            if let chip, !chip.isEmpty {
                Text(chip.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .foregroundColor(.secondary)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Merge helpers
    //
    // Mirrors the web frontend's `ContactRows` dedup/sort logic. Combines the
    // relation rows (`emails` / `phones`) with the legacy single-column fields
    // (`email` / `phone`) so neither is dropped. De-duped by lowercased email
    // value or digits-only phone (stripping a US country-code `1` if 11 digits).
    // Primary entries are sorted first.
    private struct MergedContact {
        let value: String
        let label: String
    }

    private func mergeEmails(_ p: Person) -> [MergedContact] {
        var out: [(value: String, label: String, primary: Bool)] = []
        var seen = Set<String>()
        func push(_ value: String, _ label: String, _ primary: Bool) {
            let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { return }
            let key = v.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            out.append((v, label, primary))
        }
        for e in p.emails {
            push(e.value, e.label, e.isPrimary)
        }
        if let legacy = p.email {
            push(legacy, "", false)
        }
        return out
            .sorted { (a, b) in (a.primary ? 1 : 0) > (b.primary ? 1 : 0) }
            .map { MergedContact(value: $0.value, label: $0.label) }
    }

    private func mergePhones(_ p: Person) -> [MergedContact] {
        var out: [(value: String, label: String, primary: Bool)] = []
        var seen = Set<String>()
        func normalise(_ s: String) -> String {
            let digits = s.filter { $0.isNumber }
            if digits.count == 11 && digits.hasPrefix("1") { return String(digits.dropFirst()) }
            return digits
        }
        func push(_ value: String, _ label: String, _ primary: Bool) {
            let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { return }
            let key = normalise(v)
            guard !key.isEmpty, !seen.contains(key) else { return }
            seen.insert(key)
            out.append((v, label, primary))
        }
        for ph in p.phones {
            push(ph.value, ph.label, ph.isPrimary)
        }
        if let legacy = p.phone {
            push(legacy, "", false)
        }
        return out
            .sorted { (a, b) in (a.primary ? 1 : 0) > (b.primary ? 1 : 0) }
            .map { MergedContact(value: $0.value, label: $0.label) }
    }

    @ViewBuilder
    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func timelineIcon(_ type: String) -> String {
        switch type {
        case "discussion": return "bubble.left"
        case "note":       return "note.text"
        case "task":       return "checkmark.circle"
        default:           return "circle"
        }
    }
}

// MARK: - ActivityRow

struct ActivityRow: View {
    let activity: SocialActivity

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: activity.sourceIcon)
                .foregroundColor(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(activity.source.capitalized)
                        .font(.caption).fontWeight(.semibold)
                    if let occurred = activity.occurredAt {
                        Text(occurred, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let loc = activity.location {
                        Text("· \(loc)").font(.caption2).foregroundColor(.secondary)
                    }
                }
                if let content = activity.content {
                    Text(content).font(.subheadline).lineLimit(3)
                }
            }
            Spacer()
            if let imgUrl = activity.imageUrl, let url = URL(string: imgUrl) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color(.tertiarySystemFill)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - PersonAvatarOrInitials

/// Renders the primary avatar image when `Person.avatarUrl` is set, falling
/// back to the initials-based `AvatarView`. Relative `/photos/...` URLs are
/// resolved through `APIClient.absoluteURL(forAsset:)`.
struct PersonAvatarOrInitials: View {
    let person: Person
    var size: CGFloat = 72

    var body: some View {
        if let url = APIClient.shared.absoluteURL(forAsset: person.avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure, .empty:
                    AvatarView(name: person.fullName, size: size)
                @unknown default:
                    AvatarView(name: person.fullName, size: size)
                }
            }
            .frame(width: size, height: size)
        } else {
            AvatarView(name: person.fullName, size: size)
        }
    }
}

// MARK: - DoNotContactPanel

/// Inline panel on PersonDetail that toggles the do-not-contact flag and
/// lets the user record a reason. Mirrors the web frontend's panel.
/// - Toggle saves immediately.
/// - Reason saves on focus loss (debounced via local state mirror) and
///   when the user submits the editor.
struct DoNotContactPanel: View {
    let person: Person
    @ObservedObject var vm: PersonDetailViewModel

    @State private var isOn: Bool
    @State private var reason: String
    @State private var savedReason: String
    @State private var isSaving = false

    init(person: Person, vm: PersonDetailViewModel) {
        self.person = person
        self.vm = vm
        _isOn = State(initialValue: person.doNotContact)
        _reason = State(initialValue: person.doNotContactReason ?? "")
        _savedReason = State(initialValue: person.doNotContactReason ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOn ? Color.red.opacity(0.15) : Color(.systemGray5))
                        .frame(width: 28, height: 28)
                    Image(systemName: "nosign")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isOn ? .red : Color(.systemGray))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isOn ? "Do not contact" : "Contact normally")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isOn ? .red : .primary)
                    Text(isOn
                         ? "Reminders, drafts, and cadence checks are suppressed."
                         : "Suppress reminders, drafts, and cadence checks.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.red)
                    .disabled(isSaving)
                    .onChange(of: isOn) { _, newValue in
                        Task { await saveToggle(newValue) }
                    }
            }

            if isOn {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reason (optional)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    // iOS 18: vertical-axis TextFields can render typed text in
                    // non-adaptive black, which would disappear against the
                    // previous `systemBackground` fill in dark mode.
                    TextField(
                        "e.g. asked to be removed, deceased, ex-spouse, harassment, GDPR request",
                        text: $reason,
                        axis: .vertical
                    )
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2...4)
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                    )
                    .submitLabel(.done)
                    .onSubmit { Task { await saveReason() } }
                    .onChange(of: reason) { _, _ in
                        // Debounce: 800ms after the last keystroke.
                        Task { await debouncedSaveReason() }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(isOn ? Color.red.opacity(0.06) : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOn ? Color.red.opacity(0.25) : Color.clear, lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }

    @MainActor
    private func saveToggle(_ newValue: Bool) async {
        guard newValue != person.doNotContact else { return }
        isSaving = true
        defer { isSaving = false }

        var patch = PersonPatch()
        patch.doNotContact = newValue
        if !newValue {
            // Turning off — clear the reason too.
            patch.doNotContactReason = ""
            reason = ""
            savedReason = ""
        }
        let ok = await vm.saveEdit(patch)
        if !ok {
            // Roll back the optimistic UI flip if the save failed.
            isOn = person.doNotContact
        }
    }

    private func debouncedSaveReason() async {
        let snapshot = reason
        try? await Task.sleep(nanoseconds: 800_000_000)
        // If the user kept typing, abort — a later debounce will save the final value.
        if snapshot != reason { return }
        await saveReason()
    }

    @MainActor
    private func saveReason() async {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != savedReason else { return }
        var patch = PersonPatch()
        patch.doNotContactReason = trimmed
        let ok = await vm.saveEdit(patch)
        if ok { savedReason = trimmed }
    }
}
