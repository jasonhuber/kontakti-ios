import SwiftUI

struct StrengthBadgeView: View {
    let strength: RelationshipStrength

    private var backgroundColor: Color {
        switch strength {
        case .cold:  return Color(.systemGray5)
        case .warm:  return Color.orange.opacity(0.18)
        case .hot:   return Color(red: 1.0, green: 0.35, blue: 0.1).opacity(0.18)
        case .close: return Color.green.opacity(0.18)
        }
    }

    private var foregroundColor: Color {
        switch strength {
        case .cold:  return Color(.systemGray)
        case .warm:  return .orange
        case .hot:   return Color(red: 0.9, green: 0.3, blue: 0.05)
        case .close: return .green
        }
    }

    var body: some View {
        Text(strength.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}

#Preview {
    HStack(spacing: 8) {
        StrengthBadgeView(strength: .cold)
        StrengthBadgeView(strength: .warm)
        StrengthBadgeView(strength: .hot)
        StrengthBadgeView(strength: .close)
    }
    .padding()
}
