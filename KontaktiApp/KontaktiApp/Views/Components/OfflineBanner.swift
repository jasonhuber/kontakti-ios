import SwiftUI

/// A thin banner shown at the top of list views when the device is offline.
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Offline — showing cached data")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray))
    }
}

#Preview {
    OfflineBanner()
}
