import SwiftUI

struct DiscussionDetailView: View {
    let discussion: Discussion

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(discussion.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(discussion.type.emoji) \(discussion.type.label)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(discussion.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)

                Divider()

                // Summary
                if let summary = discussion.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Summary")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(summary)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding(16)
                    Divider()
                }

                // Body
                if let body = discussion.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(body)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding(16)
                    Divider()
                }

                // Participants
                if let participants = discussion.participants, !participants.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Participants")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(participants) { person in
                                    VStack(spacing: 6) {
                                        AvatarView(name: person.fullName, size: 48)
                                        Text(person.firstName)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(discussion.type.label)
    }
}
