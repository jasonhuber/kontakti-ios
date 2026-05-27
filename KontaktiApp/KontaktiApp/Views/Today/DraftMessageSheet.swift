import SwiftUI
import UIKit

/// Channels the user can pick from "Send via" menu.
enum ReachOutChannel: String, CaseIterable, Identifiable {
    case email, sms, imessage, whatsapp, instagram, facebook, call
    case inPerson = "in_person"
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .email: return "Email"
        case .sms: return "SMS"
        case .imessage: return "iMessage"
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .facebook: return "Facebook"
        case .call: return "Call"
        case .inPerson: return "In person"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .email: return "envelope"
        case .sms: return "message"
        case .imessage: return "bubble.left.and.bubble.right"
        case .whatsapp: return "phone.circle"
        case .instagram: return "camera"
        case .facebook: return "f.cursive.circle"
        case .call: return "phone"
        case .inPerson: return "person.wave.2"
        case .other: return "ellipsis.circle"
        }
    }
}

struct DraftMessageSheet: View {
    let item: TodayItem
    @ObservedObject var vm: TodayViewModel

    @State private var messageText: String = ""
    @State private var isLoadingDraft = false
    @State private var draftError: String?
    @Environment(\.dismiss) private var dismiss

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption).foregroundColor(.secondary)
                    Text(item.person.fullName)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 12)

                if isLoadingDraft {
                    ProgressView("Drafting…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let draftError {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "nosign")
                                .font(.title3)
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Can't draft a message")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                Text(draftError)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.25), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        Spacer()
                    }
                    .padding(16)
                } else {
                    TextEditor(text: $messageText)
                        .font(.body)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(16)
                }

                if draftError == nil {
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(ReachOutChannel.allCases) { ch in
                                Button {
                                    Task { await sendVia(ch) }
                                } label: {
                                    Label(ch.label, systemImage: ch.icon)
                                }
                            }
                        } label: {
                            Label("Send via…", systemImage: "paperplane.fill")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(indigo)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            Task {
                                _ = await vm.logReachOut(item: item, via: "other", note: messageText)
                                dismiss()
                            }
                        } label: {
                            Text("Just log it")
                                .font(.body)
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(Color(.tertiarySystemFill))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemFill))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reach out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                isLoadingDraft = true
                let result = await vm.draftResult(for: item)
                switch result {
                case .success(let text):
                    messageText = text
                    draftError = nil
                case .failure(let message):
                    messageText = ""
                    draftError = message
                }
                isLoadingDraft = false
            }
        }
    }

    private func sendVia(_ channel: ReachOutChannel) async {
        // Open external app for the channel, then log.
        if let url = channelURL(channel) {
            await UIApplication.shared.open(url)
        }
        _ = await vm.logReachOut(item: item, via: channel.rawValue, note: nil)
        dismiss()
    }

    private func channelURL(_ channel: ReachOutChannel) -> URL? {
        let p = item.person
        let encodedBody = messageText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        switch channel {
        case .email:
            guard let email = p.email ?? p.emails.first?.value else { return nil }
            return URL(string: "mailto:\(email)?body=\(encodedBody)")
        case .sms, .imessage:
            guard let phone = p.phone ?? p.phones.first?.value else { return nil }
            let cleaned = phone.filter { !$0.isWhitespace }
            return URL(string: "sms:\(cleaned)&body=\(encodedBody)")
        case .whatsapp:
            guard let wa = p.whatsappPhone ?? p.phone ?? p.phones.first?.value else { return nil }
            let cleaned = wa.filter { !$0.isWhitespace && $0 != "+" }
            return URL(string: "https://wa.me/\(cleaned)?text=\(encodedBody)")
        case .instagram:
            guard let h = p.instagramHandle, !h.isEmpty else { return nil }
            return URL(string: "instagram://user?username=\(h)")
        case .facebook:
            guard let fb = p.facebookUrl, let url = URL(string: fb) else { return nil }
            return url
        case .call:
            guard let phone = p.phone ?? p.phones.first?.value else { return nil }
            let cleaned = phone.filter { !$0.isWhitespace }
            return URL(string: "tel:\(cleaned)")
        case .inPerson, .other:
            return nil
        }
    }
}
