import SwiftUI

struct PersonCardView: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: person.fullName, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(person.fullName)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if person.doNotContact {
                        DNCBadge(reason: person.doNotContactReason)
                    }
                }

                if let title = person.title, let company = person.company {
                    Text("\(title) · \(company.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if let title = person.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let company = person.company {
                    Text(company.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let lastContacted = person.lastContactedAt {
                        Text(relativeDate(lastContacted))
                            .font(.caption2)
                            .foregroundColor(Color(.systemGray2))
                    }

                    if let followup = person.nextFollowupAt {
                        let overdue = followup < Date()
                        Text("Follow up \(relativeDate(followup))")
                            .font(.caption2)
                            .foregroundColor(overdue ? .red : Color(.systemGray2))
                    }
                }
            }

            Spacer()

            StrengthBadgeView(strength: person.relationshipStrength)
        }
        .padding(.vertical, 4)
    }

    func relativeDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let components = calendar.dateComponents([.day], from: date, to: now)
        let days = abs(components.day ?? 0)

        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }
        return "\(days / 30)mo ago"
    }
}
