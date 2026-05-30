import SwiftUI

private let EMAIL_LABELS: [String] = ["work", "home", "personal", "other"]
private let PHONE_LABELS: [String] = ["mobile", "work", "home", "other"]

/// Editable row used by the email/phone repeater UI. Identifiable so SwiftUI
/// can track row identity across edits without crashing on index-based ForEach.
struct EditableContactRow: Identifiable, Hashable {
    let id: UUID
    var value: String
    var label: String
    var isPrimary: Bool

    init(id: UUID = UUID(), value: String, label: String, isPrimary: Bool) {
        self.id = id
        self.value = value
        self.label = label
        self.isPrimary = isPrimary
    }
}

/// Edits the relationship-engine extension fields on a Person plus the
/// multi-email and multi-phone collections.
struct EditPersonView: View {
    let person: Person
    var onSaved: ((Person) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var emails: [EditableContactRow]
    @State private var phones: [EditableContactRow]

    @State private var instagramHandle: String
    @State private var facebookUrl: String
    @State private var twitterXHandle: String
    @State private var tiktokHandle: String
    @State private var whatsappPhone: String

    @State private var previousEmployers: [String]
    @State private var howWeMet: String
    @State private var introducedBy: Person?
    @State private var introducedBySearch: String = ""
    @State private var introducedByResults: [Person] = []
    @State private var showIntroducedByPicker = false

    @State private var city: String
    @State private var region: String
    @State private var country: String

    @State private var contactCadence: String
    @State private var contactOnBirthday: Bool
    @State private var contactOnHolidays: Bool

    @State private var isSaving = false
    @State private var error: String?

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    private let api = APIClient.shared

    init(person: Person, onSaved: ((Person) -> Void)? = nil) {
        self.person = person
        self.onSaved = onSaved
        _emails = State(initialValue: Self.seedEmails(person))
        _phones = State(initialValue: Self.seedPhones(person))
        _instagramHandle = State(initialValue: person.instagramHandle ?? "")
        _facebookUrl = State(initialValue: person.facebookUrl ?? "")
        _twitterXHandle = State(initialValue: person.twitterXHandle ?? "")
        _tiktokHandle = State(initialValue: person.tiktokHandle ?? "")
        _whatsappPhone = State(initialValue: person.whatsappPhone ?? "")
        _previousEmployers = State(initialValue: person.previousEmployers)
        _howWeMet = State(initialValue: person.howWeMet ?? "")
        _city = State(initialValue: person.city ?? "")
        _region = State(initialValue: person.region ?? "")
        _country = State(initialValue: person.country ?? "")
        _contactCadence = State(initialValue: person.contactCadence ?? "biannual")
        _contactOnBirthday = State(initialValue: person.contactOnBirthday ?? true)
        _contactOnHolidays = State(initialValue: person.contactOnHolidays ?? false)
    }

    /// Seed editor rows from a Person — merges legacy `email` if it isn't
    /// already in the `emails` array, deduping by lowercased value.
    /// Mirrors `seedEmails` in the web frontend's EditPersonModal.tsx.
    static func seedEmails(_ p: Person) -> [EditableContactRow] {
        var out: [EditableContactRow] = []
        var seen = Set<String>()
        for e in p.emails {
            let key = e.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(EditableContactRow(value: e.value, label: e.label, isPrimary: e.isPrimary))
        }
        if let legacy = p.email {
            let key = legacy.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !key.isEmpty, !seen.contains(key) {
                out.append(EditableContactRow(value: legacy, label: "personal", isPrimary: out.isEmpty))
            }
        }
        return out
    }

    static func seedPhones(_ p: Person) -> [EditableContactRow] {
        var out: [EditableContactRow] = []
        var seen = Set<String>()
        func normalise(_ s: String) -> String {
            let digits = s.filter { $0.isNumber }
            if digits.count == 11 && digits.hasPrefix("1") { return String(digits.dropFirst()) }
            return digits
        }
        for ph in p.phones {
            let key = normalise(ph.value)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(EditableContactRow(value: ph.value, label: ph.label, isPrimary: ph.isPrimary))
        }
        if let legacy = p.phone {
            let key = normalise(legacy)
            if !key.isEmpty, !seen.contains(key) {
                out.append(EditableContactRow(value: legacy, label: "mobile", isPrimary: out.isEmpty))
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photos") {
                    // Padding-stripped so the gallery's own horizontal padding
                    // doesn't double up inside Form's section inset.
                    PhotoGalleryView(personId: person.id, editable: true)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section("Emails") {
                    contactRowsEditor(rows: $emails, labels: EMAIL_LABELS, placeholder: "email@example.com", keyboard: .emailAddress, addLabel: "Add email", defaultLabel: "personal")
                }

                Section("Phones") {
                    contactRowsEditor(rows: $phones, labels: PHONE_LABELS, placeholder: "+1 555 0123", keyboard: .phonePad, addLabel: "Add phone", defaultLabel: "mobile")
                }

                Section("Social") {
                    HStack {
                        Text("@").foregroundColor(.secondary)
                        TextField("instagram_handle", text: $instagramHandle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    TextField("Facebook URL", text: $facebookUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    HStack {
                        Text("@").foregroundColor(.secondary)
                        TextField("twitter / x handle", text: $twitterXHandle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    HStack {
                        Text("@").foregroundColor(.secondary)
                        TextField("tiktok handle", text: $tiktokHandle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    TextField("WhatsApp phone", text: $whatsappPhone)
                        .keyboardType(.phonePad)
                }

                Section("Career") {
                    ForEach(previousEmployers.indices, id: \.self) { idx in
                        HStack {
                            TextField("Previous employer", text: $previousEmployers[idx])
                            Button {
                                previousEmployers.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                        }
                    }
                    Button {
                        previousEmployers.append("")
                    } label: {
                        Label("Add previous employer", systemImage: "plus.circle")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How we met").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $howWeMet).frame(minHeight: 80)
                    }

                    HStack {
                        Text("Introduced by")
                        Spacer()
                        Button {
                            showIntroducedByPicker = true
                        } label: {
                            Text(introducedBy?.fullName ?? "Choose…")
                                .foregroundColor(introducedBy == nil ? .secondary : indigo)
                        }
                    }
                    if introducedBy != nil {
                        Button(role: .destructive) {
                            introducedBy = nil
                        } label: { Text("Clear introducer") }
                    }
                }

                Section("Stay in touch") {
                    Picker("Reach out", selection: $contactCadence) {
                        Text("Monthly").tag("monthly")
                        Text("Every 3 months").tag("quarterly")
                        Text("Twice a year").tag("biannual")
                        Text("Once a year").tag("annual")
                        Text("No reminders").tag("none")
                    }
                    Toggle("Remind me on their birthday", isOn: $contactOnBirthday)
                    Toggle("Remind me around the holidays", isOn: $contactOnHolidays)
                }

                Section("Location") {
                    TextField("City", text: $city)
                    TextField("Region / State", text: $region)
                    TextField("Country", text: $country)
                }

                if let error {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("Edit \(person.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await save() } } label: {
                        if isSaving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showIntroducedByPicker) {
                PersonSearchPicker(excluding: person.id) { picked in
                    introducedBy = picked
                    showIntroducedByPicker = false
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // Strip empty rows and trim values. Normalise the primary flag: if
        // none are flagged, mark the first; if multiple are flagged, keep
        // just the first. Mirrors the web frontend's `ensurePrimary`.
        let cleanEmails = normalisedRows(emails)
        let cleanPhones = normalisedRows(phones)

        // Mirror the primary value into the legacy single-column fields so
        // list/search views (and the SwiftData cache) keep showing the right
        // address even though they only read the legacy column.
        let primaryEmail = cleanEmails.first(where: { $0.isPrimary })?.value
        let primaryPhone = cleanPhones.first(where: { $0.isPrimary })?.value

        var patch = PersonPatch()
        patch.email = primaryEmail
        patch.phone = primaryPhone
        patch.emails = cleanEmails.map { PersonEmailPatch(value: $0.value, label: $0.label, isPrimary: $0.isPrimary) }
        patch.phones = cleanPhones.map { PersonPhonePatch(value: $0.value, label: $0.label, isPrimary: $0.isPrimary) }
        patch.instagramHandle = trimmedOrNil(instagramHandle.replacingOccurrences(of: "@", with: ""))
        patch.facebookUrl = trimmedOrNil(facebookUrl)
        patch.twitterXHandle = trimmedOrNil(twitterXHandle.replacingOccurrences(of: "@", with: ""))
        patch.tiktokHandle = trimmedOrNil(tiktokHandle.replacingOccurrences(of: "@", with: ""))
        patch.whatsappPhone = trimmedOrNil(whatsappPhone)
        patch.previousEmployers = previousEmployers
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        patch.howWeMet = trimmedOrNil(howWeMet)
        patch.introducedById = introducedBy?.id
        patch.city = trimmedOrNil(city)
        patch.region = trimmedOrNil(region)
        patch.country = trimmedOrNil(country)
        patch.contactCadence = contactCadence
        patch.contactOnBirthday = contactOnBirthday
        patch.contactOnHolidays = contactOnHolidays

        do {
            let updated = try await api.updatePerson(id: person.id, patch: patch)
            onSaved?(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Trim values, drop empty rows, then guarantee at most one primary.
    private func normalisedRows(_ rows: [EditableContactRow]) -> [EditableContactRow] {
        let trimmed: [EditableContactRow] = rows.compactMap {
            let v = $0.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { return nil }
            return EditableContactRow(id: $0.id, value: v, label: $0.label, isPrimary: $0.isPrimary)
        }
        guard !trimmed.isEmpty else { return [] }
        let firstPrimary = trimmed.firstIndex(where: { $0.isPrimary }) ?? 0
        return trimmed.enumerated().map { idx, row in
            EditableContactRow(id: row.id, value: row.value, label: row.label, isPrimary: idx == firstPrimary)
        }
    }

    private func trimmedOrNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    // MARK: - Contact rows editor

    @ViewBuilder
    private func contactRowsEditor(
        rows: Binding<[EditableContactRow]>,
        labels: [String],
        placeholder: String,
        keyboard: UIKeyboardType,
        addLabel: String,
        defaultLabel: String
    ) -> some View {
        ForEach(rows.wrappedValue.indices, id: \.self) { idx in
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    TextField(placeholder, text: rows[idx].value)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        // Make this row the sole primary.
                        var next = rows.wrappedValue
                        for j in next.indices { next[j].isPrimary = j == idx }
                        rows.wrappedValue = next
                    } label: {
                        Image(systemName: rows.wrappedValue[idx].isPrimary ? "star.fill" : "star")
                            .foregroundColor(rows.wrappedValue[idx].isPrimary ? indigo : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(rows.wrappedValue[idx].isPrimary ? "Primary" : "Make primary")
                    Button {
                        rows.wrappedValue.remove(at: idx)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove")
                }
                Picker("Label", selection: rows[idx].label) {
                    ForEach(labels, id: \.self) { l in
                        Text(l.capitalized).tag(l)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 2)
        }
        Button {
            let isFirst = rows.wrappedValue.isEmpty
            rows.wrappedValue.append(
                EditableContactRow(value: "", label: defaultLabel, isPrimary: isFirst)
            )
        } label: {
            Label(addLabel, systemImage: "plus.circle")
        }
    }
}

// MARK: - PersonSearchPicker

struct PersonSearchPicker: View {
    var excluding: String? = nil
    let onPick: (Person) -> Void

    @State private var query: String = ""
    @State private var results: [Person] = []
    @State private var isSearching = false
    @Environment(\.dismiss) private var dismiss

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            List {
                if isSearching { ProgressView() }
                ForEach(results) { p in
                    Button {
                        onPick(p)
                        dismiss()
                    } label: {
                        HStack {
                            AvatarView(name: p.fullName, size: 32)
                            VStack(alignment: .leading) {
                                Text(p.fullName)
                                if let t = p.title { Text(t).font(.caption).foregroundColor(.secondary) }
                            }
                        }
                    }
                }
                if !isSearching && results.isEmpty && !query.isEmpty {
                    Text("No matches").foregroundColor(.secondary)
                }
            }
            .searchable(text: $query, prompt: "Search people")
            .onChange(of: query) {
                Task { await search() }
            }
            .navigationTitle("Pick person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            let people = try await api.searchPeople(query: q)
            results = people.filter { $0.id != excluding }
        } catch {
            results = []
        }
    }
}
