import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(Color(.systemGray3))
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "person.2",
        title: "No contacts",
        subtitle: "Add people to get started"
    )
}
