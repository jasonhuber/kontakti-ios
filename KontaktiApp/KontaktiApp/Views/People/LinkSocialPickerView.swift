import SwiftUI

/// Payload extracted from the share extension's `kontakti://link-social` URL.
struct LinkSocialPayload: Equatable, Identifiable {
    enum Platform: String { case instagram, facebook, twitter, tiktok }

    let id = UUID()
    let platform: Platform
    let handle: String?      // for handle-based platforms
    let url: String?         // for URL-based platforms (facebook)

    var displayValue: String { handle.map { "@\($0)" } ?? url ?? "" }

    static func fromURL(_ url: URL) -> LinkSocialPayload? {
        guard url.scheme?.lowercased() == "kontakti",
              url.host == "link-social" else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = comps?.queryItems ?? []
        func val(_ n: String) -> String? {
            items.first(where: { $0.name == n })?.value
        }
        guard let platformRaw = val("platform"),
              let platform = Platform(rawValue: platformRaw.lowercased()) else { return nil }
        return LinkSocialPayload(platform: platform, handle: val("handle"), url: val("url"))
    }
}

struct LinkSocialPickerView: View {
    let payload: LinkSocialPayload
    var onLinked: (Person) -> Void = { _ in }

    @State private var query: String = ""
    @State private var results: [Person] = []
    @State private var isSearching = false
    @State private var isLinking = false
    @State private var error: String?
    @State private var toast: String?
    @State private var showingCreate = false

    @Environment(\.dismiss) private var dismiss

    private let api = APIClient.shared
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header: detected social signal
                VStack(spacing: 6) {
                    Image(systemName: platformIcon)
                        .font(.system(size: 36))
                        .foregroundColor(indigo)
                    Text("Link \(payload.platform.rawValue.capitalized)")
                        .font(.headline)
                    Text(payload.displayValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemGroupedBackground))

                List {
                    Section("Pick a person to link") {
                        Button {
                            showingCreate = true
                        } label: {
                            Label("Create new person", systemImage: "person.crop.circle.badge.plus")
                                .foregroundColor(indigo)
                        }
                        if isSearching { ProgressView() }
                        ForEach(results) { p in
                            Button {
                                Task { await link(to: p) }
                            } label: {
                                HStack {
                                    AvatarView(name: p.fullName, size: 32)
                                    VStack(alignment: .leading) {
                                        Text(p.fullName).foregroundColor(.primary)
                                        if let t = p.title { Text(t).font(.caption).foregroundColor(.secondary) }
                                    }
                                    Spacer()
                                    if isLinking { ProgressView() }
                                }
                            }
                            .disabled(isLinking)
                        }
                        if let error {
                            Text(error).foregroundColor(.red).font(.caption)
                        }
                    }
                }
                .searchable(text: $query, prompt: "Search people")
                .onChange(of: query) { _ in Task { await search() } }
            }
            .navigationTitle("Link social")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreatePersonWithSocialSheet(payload: payload) { newPerson in
                    showingCreate = false
                    onLinked(newPerson)
                    dismiss()
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private var platformIcon: String {
        switch payload.platform {
        case .instagram: return "camera"
        case .facebook: return "f.cursive.circle"
        case .twitter: return "bird"
        case .tiktok: return "music.note"
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await api.searchPeople(query: q)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func link(to person: Person) async {
        isLinking = true
        defer { isLinking = false }
        var patch = PersonPatch()
        switch payload.platform {
        case .instagram: patch.instagramHandle = payload.handle
        case .facebook: patch.facebookUrl = payload.url
        case .twitter: patch.twitterXHandle = payload.handle
        case .tiktok: patch.tiktokHandle = payload.handle
        }
        do {
            let updated = try await api.updatePerson(id: person.id, patch: patch)
            toast = "Linked \(payload.platform.rawValue) to \(updated.fullName)"
            onLinked(updated)
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - CreatePersonWithSocialSheet

private struct CreatePersonWithSocialSheet: View {
    let payload: LinkSocialPayload
    let onCreated: (Person) -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("New person") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }
                Section("Social") {
                    Text("\(payload.platform.rawValue.capitalized): \(payload.displayValue)")
                        .font(.subheadline)
                }
                if let error {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("Create person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func create() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let req = CreatePersonRequest(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.isEmpty ? nil : lastName,
                email: nil, phone: nil, linkedinUrl: nil, avatarUrl: nil,
                title: nil, companyName: nil, notes: nil
            )
            let created = try await api.createPerson(req)

            // Apply the social field via PATCH.
            var patch = PersonPatch()
            switch payload.platform {
            case .instagram: patch.instagramHandle = payload.handle
            case .facebook: patch.facebookUrl = payload.url
            case .twitter: patch.twitterXHandle = payload.handle
            case .tiktok: patch.tiktokHandle = payload.handle
            }
            let updated = try await api.updatePerson(id: created.id, patch: patch)
            onCreated(updated)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
