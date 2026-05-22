import SwiftUI

struct PersonDetailView: View {
    let person: Person
    @StateObject private var vm = PersonDetailViewModel()

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
                    AvatarView(name: displayPerson.fullName, size: 72)
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

                // Stats row
                HStack(spacing: 0) {
                    statCell(value: displayPerson.discussionsCount ?? 0, label: "Discussions")
                    Divider().frame(height: 36)
                    statCell(value: displayPerson.tasksCount ?? 0, label: "Tasks")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Contact info
                if displayPerson.email != nil || displayPerson.phone != nil || displayPerson.linkedinUrl != nil {
                    GroupBox {
                        VStack(spacing: 0) {
                            if let email = displayPerson.email {
                                contactRow(
                                    icon: "envelope",
                                    label: email,
                                    url: URL(string: "mailto:\(email)")
                                )
                            }
                            if displayPerson.email != nil && displayPerson.phone != nil {
                                Divider().padding(.leading, 36)
                            }
                            if let phone = displayPerson.phone {
                                contactRow(
                                    icon: "phone",
                                    label: phone,
                                    url: URL(string: "tel:\(phone.filter { !$0.isWhitespace })")
                                )
                            }
                            if displayPerson.phone != nil && displayPerson.linkedinUrl != nil {
                                Divider().padding(.leading, 36)
                            }
                            if let linkedin = displayPerson.linkedinUrl, let url = URL(string: linkedin) {
                                contactRow(icon: "globe", label: "LinkedIn", url: url)
                            }
                        }
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

                // Notes
                if let notes = displayPerson.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        GroupBox {
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
    }

    @ViewBuilder
    private func contactRow(icon: String, label: String, url: URL?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(indigo)
                .frame(width: 24)
            if let url {
                Link(label, destination: url)
                    .font(.subheadline)
                    .foregroundColor(indigo)
            } else {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
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
