import SwiftUI

struct LogDiscussionView: View {
    @ObservedObject var vm: DiscussionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()
    @State private var type: DiscussionType = .call
    @State private var summary = ""
    @State private var participantSearch = ""
    @State private var searchResults: [Person] = []
    @State private var selectedParticipants: Set<String> = []
    @State private var isSearching = false
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var showingError = false

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        NavigationStack {
            Form {
                Section("Discussion") {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Type", selection: $type) {
                        ForEach(DiscussionType.allCases, id: \.self) { t in
                            Text("\(t.emoji) \(t.label)").tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Summary") {
                    ZStack(alignment: .topLeading) {
                        if summary.isEmpty {
                            Text("What was discussed?")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $summary)
                            .frame(minHeight: 80)
                    }
                }

                Section("Participants") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search people...", text: $participantSearch)
                            .onChange(of: participantSearch) { query in
                                guard query.count >= 2 else {
                                    searchResults = []
                                    return
                                }
                                Task { await searchPeople(query: query) }
                            }
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    if !searchResults.isEmpty {
                        ForEach(searchResults) { person in
                            Button {
                                toggleParticipant(person)
                            } label: {
                                HStack {
                                    AvatarView(name: person.fullName, size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person.fullName)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        if let title = person.title {
                                            Text(title)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedParticipants.contains(person.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(indigo)
                                    }
                                }
                            }
                        }
                    }

                    if !selectedParticipants.isEmpty {
                        let selectedPeople = searchResults.filter { selectedParticipants.contains($0.id) }
                        if !selectedPeople.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedPeople) { person in
                                        HStack(spacing: 4) {
                                            AvatarView(name: person.fullName, size: 24)
                                            Text(person.firstName)
                                                .font(.caption)
                                            Button {
                                                selectedParticipants.remove(person.id)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Discussion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .overlay {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong. Please try again.")
            }
        }
    }

    private func toggleParticipant(_ person: Person) {
        if selectedParticipants.contains(person.id) {
            selectedParticipants.remove(person.id)
        } else {
            selectedParticipants.insert(person.id)
        }
    }

    private func searchPeople(query: String) async {
        isSearching = true
        do {
            searchResults = try await APIClient.shared.searchPeople(query: query)
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true
        do {
            let participantIds = Array(selectedParticipants)
            try await vm.createDiscussion(
                title: trimmedTitle,
                date: date,
                type: type,
                summary: summary.isEmpty ? nil : summary,
                participantIds: participantIds
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        isSaving = false
    }
}
