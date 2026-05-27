import SwiftUI

/// Post-import duplicate review. Mirrors the web UX in mobile-native form:
///   - Expandable candidate rows
///   - Side-by-side / stacked person comparison
///   - AI confidence pill + verdict
///   - Primary picker (tap a person to set as primary)
///   - Field-level "use this value" pickers for conflicts
///   - Merge / Keep separate / Skip actions
struct DuplicateReviewView: View {
    @StateObject private var vm = DuplicateReviewViewModel()
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        Group {
            if vm.isLoading && vm.candidates.isEmpty {
                ProgressView("Loading duplicates…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.candidates.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal",
                    title: "No duplicates",
                    subtitle: "We didn't find any potential duplicates. Run a scan to look again."
                )
            } else {
                List {
                    ForEach(vm.candidates) { candidate in
                        DuplicateRow(candidate: candidate, vm: vm)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Review duplicates")
        .navigationBarTitleDisplayMode(.inline)
        .tint(indigo)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await vm.scan() }
                } label: {
                    if vm.isScanning {
                        ProgressView()
                    } else {
                        Label("Find", systemImage: "sparkles")
                    }
                }
                .disabled(vm.isScanning)
            }
        }
        .overlay(alignment: .top) {
            if let banner = vm.banner {
                Text(banner)
                    .font(.footnote)
                    .padding(8)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                    .padding(.top, 4)
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .onAppear {
            ContactsImporter.shared.hasUnreviewedDuplicates = false
        }
    }
}

// MARK: - Row

private struct DuplicateRow: View {
    let candidate: DuplicateCandidate
    @ObservedObject var vm: DuplicateReviewViewModel
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // AI verdict pill
                if let decision = candidate.aiDecision {
                    HStack(spacing: 6) {
                        Text(decision.decision.uppercased())
                            .font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(decision.decision == "merge" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .foregroundColor(decision.decision == "merge" ? .green : .orange)
                            .clipShape(Capsule())
                        Text("AI confidence: \(Int(decision.confidence * 100))%")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    if !decision.reasoning.isEmpty {
                        Text(decision.reasoning)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // People cards — tap to pick primary
                ForEach(candidate.people) { person in
                    PersonCard(
                        person: person,
                        isPrimary: vm.primaryId(for: candidate) == person.id,
                        onTap: { vm.setPrimary(person.id, for: candidate) }
                    )
                }

                // Field-level merged editor
                MergedFieldEditor(
                    candidate: candidate,
                    merged: Binding(
                        get: { vm.mergedFields(for: candidate) },
                        set: { vm.setMerged($0, for: candidate) }
                    )
                )

                // Actions
                HStack(spacing: 12) {
                    Button {
                        Task { await vm.merge(candidate) }
                    } label: {
                        Text("Merge").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await vm.dismiss(candidate) }
                    } label: {
                        Text("Keep separate").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        vm.skip(candidate)
                    } label: {
                        Text("Skip").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.people.map(\.fullName).joined(separator: " ↔︎ "))
                    .font(.body)
                    .lineLimit(2)
                if let conf = candidate.aiConfidence {
                    Text("AI: \(Int(conf * 100))%")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct PersonCard: View {
    let person: Person
    let isPrimary: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.fullName).font(.subheadline).bold()
                    if let email = person.email { Text(email).font(.caption).foregroundColor(.secondary) }
                    if let phone = person.phone { Text(phone).font(.caption).foregroundColor(.secondary) }
                    if let company = person.company?.name { Text(company).font(.caption).foregroundColor(.secondary) }
                }
                Spacer()
                Image(systemName: isPrimary ? "star.fill" : "star")
                    .foregroundColor(isPrimary ? .yellow : .gray)
            }
            .padding(8)
            .background(isPrimary ? Color.yellow.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

private struct MergedFieldEditor: View {
    let candidate: DuplicateCandidate
    @Binding var merged: MergedFields

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Merged values").font(.caption).foregroundColor(.secondary)

            FieldPicker(label: "First name",
                        value: $merged.firstName,
                        options: candidate.people.compactMap { $0.firstName.isEmpty ? nil : $0.firstName })
            FieldPicker(label: "Last name",
                        value: $merged.lastName,
                        options: candidate.people.compactMap { $0.lastName.isEmpty ? nil : $0.lastName })
            FieldPicker(label: "Email",
                        value: $merged.email,
                        options: candidate.people.compactMap(\.email))
            FieldPicker(label: "Phone",
                        value: $merged.phone,
                        options: candidate.people.compactMap(\.phone))
            FieldPicker(label: "Company",
                        value: $merged.companyName,
                        options: candidate.people.compactMap { $0.company?.name })
        }
    }
}

private struct FieldPicker: View {
    let label: String
    @Binding var value: String?
    let options: [String]

    var body: some View {
        if options.isEmpty {
            EmptyView()
        } else {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                Picker("", selection: Binding(
                    get: { value ?? options.first ?? "" },
                    set: { value = $0 }
                )) {
                    ForEach(Array(Set(options)), id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer()
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class DuplicateReviewViewModel: ObservableObject {
    @Published var candidates: [DuplicateCandidate] = []
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var banner: String?
    @Published var error: String?

    private var primaryOverrides: [Int: String] = [:]
    private var mergedOverrides: [Int: MergedFields] = [:]
    private var skipped: Set<Int> = []

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await api.listDuplicates()
            self.candidates = all.filter { !skipped.contains($0.id) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func scan() async {
        isScanning = true
        defer { isScanning = false }
        do {
            let (generated, aiResolved) = try await api.scanDuplicates()
            banner = "Scan complete: \(generated) candidates, \(aiResolved) auto-resolved."
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func primaryId(for candidate: DuplicateCandidate) -> String {
        primaryOverrides[candidate.id]
            ?? candidate.aiDecision?.primaryId
            ?? candidate.personIds.first
            ?? ""
    }

    func setPrimary(_ id: String, for candidate: DuplicateCandidate) {
        primaryOverrides[candidate.id] = id
        objectWillChange.send()
    }

    func mergedFields(for candidate: DuplicateCandidate) -> MergedFields {
        if let override = mergedOverrides[candidate.id] { return override }
        if let ai = candidate.aiDecision?.merged { return ai }
        // Fall back to the chosen primary person's values.
        let primaryId = primaryId(for: candidate)
        let person = candidate.people.first(where: { $0.id == primaryId }) ?? candidate.people.first
        return MergedFields(
            firstName: person?.firstName,
            lastName: person?.lastName,
            email: person?.email,
            phone: person?.phone,
            companyName: person?.company?.name
        )
    }

    func setMerged(_ merged: MergedFields, for candidate: DuplicateCandidate) {
        mergedOverrides[candidate.id] = merged
        objectWillChange.send()
    }

    func merge(_ candidate: DuplicateCandidate) async {
        let primary = primaryId(for: candidate)
        let merged = mergedFields(for: candidate)
        do {
            _ = try await api.mergeDuplicate(id: candidate.id, primaryId: primary, merged: merged)
            candidates.removeAll { $0.id == candidate.id }
            banner = "Merged."
        } catch {
            self.error = error.localizedDescription
        }
    }

    func dismiss(_ candidate: DuplicateCandidate) async {
        do {
            try await api.dismissDuplicate(id: candidate.id)
            candidates.removeAll { $0.id == candidate.id }
            banner = "Kept separate."
        } catch {
            self.error = error.localizedDescription
        }
    }

    func skip(_ candidate: DuplicateCandidate) {
        skipped.insert(candidate.id)
        candidates.removeAll { $0.id == candidate.id }
    }
}

#Preview {
    NavigationStack { DuplicateReviewView() }
}
