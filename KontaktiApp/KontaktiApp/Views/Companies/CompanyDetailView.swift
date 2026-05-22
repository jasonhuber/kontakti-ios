import SwiftUI

struct CompanyDetailView: View {
    let company: Company
    @State private var people: [Person] = []
    @State private var isLoading = false

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 72, height: 72)
                        Image(systemName: "building.2")
                            .font(.system(size: 32))
                            .foregroundColor(Color(.systemGray))
                    }

                    Text(company.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let domain = company.domain {
                        Text(domain)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        if let industry = company.industry {
                            Text(industry)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(indigo.opacity(0.12))
                                .foregroundColor(indigo)
                                .clipShape(Capsule())
                        }

                        if let sizeRange = company.sizeRange {
                            Text(sizeRange)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .foregroundColor(.secondary)
                                .clipShape(Capsule())
                        }
                    }

                    if let website = company.website, let url = URL(string: website) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                Text(website)
                            }
                            .font(.caption)
                            .foregroundColor(indigo)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)

                // People section
                if isLoading {
                    ProgressView()
                        .padding()
                } else if !people.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("People")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(people) { person in
                                    NavigationLink(value: person) {
                                        VStack(spacing: 6) {
                                            AvatarView(name: person.fullName, size: 48)
                                            Text(person.firstName)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.bottom, 16)
                    .navigationDestination(for: Person.self) { person in
                        PersonDetailView(person: person)
                    }
                }

                // Tags
                if !company.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(company.tags) { tag in
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

                // Notes
                if let notes = company.notes, !notes.isEmpty {
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
        .task {
            isLoading = true
            do {
                people = try await APIClient.shared.getCompanyPeople(company.id)
            } catch {
                // Fail gracefully — people section stays empty
            }
            isLoading = false
        }
    }
}
