import SwiftUI

/// Reusable picker row for a social group (Facebook or WhatsApp).
/// Shows avatar, name, optional member count, optional admin badge,
/// and a trailing checkmark when selected.
struct GroupPickRow: View {
    let name: String
    let memberCount: Int?
    let avatarUrl: String?
    let isSelected: Bool
    var isAdmin: Bool? = nil
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let count = memberCount {
                            Text("\(count) members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if isAdmin == true {
                            Text("Admin")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? Color(red: 0.31, green: 0.27, blue: 0.90) : Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlString = avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    placeholder
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            placeholder
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "person.3.fill")
                .foregroundColor(.secondary)
        }
    }
}
