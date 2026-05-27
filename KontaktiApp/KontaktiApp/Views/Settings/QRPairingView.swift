import SwiftUI
import UIKit

/// Reusable QR display + polling component for in-app pairing flows
/// (currently WhatsApp Linked Devices).
///
/// State machine (driven by injected closures):
///   load(.qr)   -> renders QR, starts countdown if expires_in_seconds present
///   tick every 3s -> load(.status); if paired -> onPaired() and stop
///   on countdown == 0 -> load(.qr) again to refresh
///
/// The host owns the dismissal / next-step transition through `onPaired`.
struct QRPairingView: View {
    let title: String
    let instructions: [String]
    let fetchQR: () async throws -> WhatsappQR
    let fetchStatus: () async throws -> WhatsappStatus
    let onPaired: () -> Void

    @State private var qr: WhatsappQR?
    @State private var remaining: Int?
    @State private var errorMessage: String?
    @State private var isRefreshing = false

    private let pollInterval: UInt64 = 3 * 1_000_000_000 // 3s
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2.bold())

            qrImageView
                .frame(width: 240, height: 240)
                .padding(8)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let remaining {
                Text("Expires in \(remaining)s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { idx, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.subheadline.bold())
                            .foregroundColor(indigo)
                        Text(line)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button {
                Task { await refreshQR() }
            } label: {
                HStack {
                    if isRefreshing { ProgressView().scaleEffect(0.8) }
                    Text("Refresh code")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task { await refreshQR() }
        .task { await pollStatus() }
        .task { await countdownTicker() }
    }

    @ViewBuilder
    private var qrImageView: some View {
        if let image = decodeQR(qr?.qrDataUrl) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            ZStack {
                Color(.systemGray6)
                if qr == nil {
                    ProgressView()
                } else {
                    Image(systemName: "qrcode")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func decodeQR(_ dataUrl: String?) -> UIImage? {
        guard let s = dataUrl else { return nil }
        // Strip a "data:...;base64," prefix if present.
        let base64: String
        if let commaIdx = s.firstIndex(of: ",") {
            base64 = String(s[s.index(after: commaIdx)...])
        } else {
            base64 = s
        }
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func refreshQR() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let result = try await fetchQR()
            if result.paired {
                onPaired()
                return
            }
            qr = result
            remaining = result.expiresInSeconds
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pollStatus() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: pollInterval)
            if Task.isCancelled { return }
            do {
                let status = try await fetchStatus()
                if status.paired {
                    onPaired()
                    return
                }
            } catch {
                // Silent — surfaced via explicit refresh.
            }
        }
    }

    private func countdownTicker() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            if let r = remaining {
                if r <= 1 {
                    remaining = nil
                    await refreshQR()
                } else {
                    remaining = r - 1
                }
            }
        }
    }
}
