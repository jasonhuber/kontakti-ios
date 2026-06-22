import SwiftUI

private struct QuickLogOption: Identifiable {
    let id: String
    let via: String
    let label: String
    let systemImage: String
}

private let quickLogOptions: [QuickLogOption] = [
    QuickLogOption(id: "phone",     via: "phone",     label: "Called",    systemImage: "phone.fill"),
    QuickLogOption(id: "sms",       via: "sms",       label: "Texted",    systemImage: "message.fill"),
    QuickLogOption(id: "imessage",  via: "imessage",  label: "iMessage",  systemImage: "bubble.left.fill"),
    QuickLogOption(id: "email",     via: "email",     label: "Emailed",   systemImage: "envelope.fill"),
    QuickLogOption(id: "in_person", via: "in_person", label: "In person", systemImage: "person.2.fill"),
    QuickLogOption(id: "facebook",  via: "facebook",  label: "Facebook",  systemImage: "hand.thumbsup.fill"),
    QuickLogOption(id: "whatsapp",  via: "whatsapp",  label: "WhatsApp",  systemImage: "checkmark.bubble.fill"),
]

/// Horizontal scrolling row of quick-log chips for a person.
/// One tap writes to reach_out_log and updates last_contacted_at without
/// requiring the person to be in the Today queue.
struct QuickLogBarView: View {
    let personId: String

    @State private var loggedVia: String? = nil
    @State private var isPending = false
    @State private var errorMessage: String? = nil

    private let api = APIClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick log")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickLogOptions) { option in
                        chipButton(option)
                    }
                }
                .padding(.horizontal, 16)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func chipButton(_ option: QuickLogOption) -> some View {
        let isLogged = loggedVia == option.via
        Button {
            guard !isPending else { return }
            Task { await tap(option.via) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isLogged ? "checkmark" : option.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(isLogged ? "Done!" : option.label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isLogged ? Color.green : Color(.systemGroupedBackground))
            .foregroundColor(isLogged ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isLogged ? Color.green : Color(.separator), lineWidth: 1)
            )
        }
        .disabled(isPending)
    }

    private func tap(_ via: String) async {
        isPending = true
        errorMessage = nil
        do {
            try await api.logContactDirect(personId: personId, via: via)
            loggedVia = via
            // Clear the "Done!" state after 2 seconds.
            try await Task.sleep(nanoseconds: 2_000_000_000)
            loggedVia = nil
        } catch {
            errorMessage = "Couldn't log contact. Try again."
        }
        isPending = false
    }
}
