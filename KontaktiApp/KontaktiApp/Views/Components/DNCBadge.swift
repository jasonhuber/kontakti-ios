import SwiftUI

/// Small red "DNC" pill shown next to a person's name when they're marked
/// do-not-contact. Hover tooltip would show the reason on desktop; on iOS
/// we surface the reason in the detail view's DNC panel instead.
struct DNCBadge: View {
    let reason: String?

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "nosign")
                .font(.system(size: 8, weight: .bold))
            Text("DNC")
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.red.opacity(0.12))
        .foregroundColor(.red)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.red.opacity(0.25), lineWidth: 0.5)
        )
        .accessibilityLabel(reason.map { "Do not contact: \($0)" } ?? "Do not contact")
    }
}

#Preview {
    VStack(spacing: 8) {
        DNCBadge(reason: nil)
        DNCBadge(reason: "asked to be removed")
    }
    .padding()
}
