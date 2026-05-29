import SwiftUI

// MARK: - View model

@MainActor
final class ReviewContactsViewModel: ObservableObject {
    @Published var health: PeopleHealth?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            health = try await api.getPeopleHealth()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Top-level review screen

struct ReviewContactsView: View {
    @StateObject private var vm = ReviewContactsViewModel()

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    /// Display order — also drives section ordering on screen. Buckets that
    /// the server omits are simply skipped.
    private static let bucketOrder: [(key: String, label: String, icon: String)] = [
        ("needs_review",         "Flagged on import",   "exclamationmark.circle"),
        ("missing_first_name",   "Missing first name",  "person.crop.circle.badge.questionmark"),
        ("missing_last_name",    "Missing last name",   "person.crop.circle.badge.questionmark"),
        ("missing_contact_info", "No email or phone",   "envelope.badge"),
        ("invalid_email",        "Suspect email",       "envelope.badge.shield.half.filled"),
        ("duplicate_email",      "Duplicate emails",    "rectangle.on.rectangle"),
        ("unlinked_company",     "Company not linked",  "building.2"),
        ("imported_unreviewed",  "Imported, unreviewed","tray.and.arrow.down"),
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            content
        }
        .navigationTitle("Review contacts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.health == nil {
            ProgressView()
        } else if let error = vm.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundColor(.orange)
                Text(error).font(.callout).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        } else if let health = vm.health {
            List {
                Section {
                    HStack {
                        Text("Total contacts").font(.body).foregroundColor(.primary)
                        Spacer()
                        Text("\(health.total)")
                            .font(.body).fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Needs cleanup") {
                    let visibleBuckets = Self.bucketOrder.compactMap { entry -> (String, String, String, HealthBucket)? in
                        guard let b = health.buckets[entry.key], b.count > 0 else { return nil }
                        return (entry.key, entry.label, entry.icon, b)
                    }
                    if visibleBuckets.isEmpty {
                        Text("Everything looks clean — no rows flagged.")
                            .font(.body).foregroundColor(.secondary)
                    } else {
                        ForEach(visibleBuckets, id: \.0) { (key, label, icon, bucket) in
                            NavigationLink {
                                ReviewBucketView(bucketKey: key, label: label, bucket: bucket)
                            } label: {
                                BucketRow(label: label, icon: icon, count: bucket.count, tint: indigo)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Row + per-bucket detail

private struct BucketRow: View {
    let label: String
    let icon: String
    let count: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundColor(tint).font(.body)
            }
            Text(label).foregroundColor(.primary)
            Spacer()
            Text("\(count)")
                .font(.callout).fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct ReviewBucketView: View {
    let bucketKey: String
    let label: String
    let bucket: HealthBucket

    var body: some View {
        List {
            Section {
                Text("\(bucket.count) total")
                    .font(.callout).foregroundColor(.secondary)
            }
            Section("Sample") {
                if bucket.samples.isEmpty {
                    Text("No rows in this bucket.").foregroundColor(.secondary)
                } else {
                    ForEach(bucket.samples) { sample in
                        SampleRow(sample: sample)
                    }
                }
            }
            if bucket.count > bucket.samples.count {
                Section {
                    Text("Showing \(bucket.samples.count) of \(bucket.count). Open the People tab and filter by ‘needs_review’ to see the rest.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SampleRow: View {
    let sample: HealthSample

    @State private var isMarking = false
    @State private var didMark = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sample.displayName).font(.body).foregroundColor(.primary)
                if let email = sample.email, !email.isEmpty {
                    Text(email).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if didMark {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            } else if isMarking {
                ProgressView().scaleEffect(0.8)
            } else {
                Button {
                    Task { await markReviewed() }
                } label: {
                    Text("Reviewed").font(.caption).fontWeight(.semibold)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func markReviewed() async {
        isMarking = true
        _ = try? await APIClient.shared.markPersonReviewed(id: sample.id)
        didMark = true
        isMarking = false
    }
}
