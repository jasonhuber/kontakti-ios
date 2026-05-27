import SwiftUI

/// Sheet that records a voice memo, uploads it to /voice/capture, and presents
/// the AI-extracted review screen.
struct VoiceRecordingView: View {
    let personId: String?
    let context: String?

    @StateObject private var recorder = VoiceRecorder()
    @Environment(\.dismiss) private var dismiss

    @State private var pulse = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var result: VoiceCaptureResult?

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    init(personId: String? = nil, context: String? = nil) {
        self.personId = personId
        self.context = context
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(indigo.opacity(0.18))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .opacity(pulse ? 0.4 : 1.0)
                        .animation(
                            isRecording
                                ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                                : .default,
                            value: pulse
                        )

                    Circle()
                        .fill(indigo)
                        .frame(width: 140, height: 140)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.white)
                }

                Text(timeString(recorder.elapsedSeconds))
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)

                Text(statusLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let err = uploadError {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        recorder.cancel()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.tertiarySystemFill))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    .disabled(isUploading)

                    Button {
                        Task { await stopAndUpload() }
                    } label: {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "stop.fill")
                            }
                            Text(isUploading ? "Transcribing…" : "Stop")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(indigo)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(!isRecording || isUploading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Voice memo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $result) { res in
                VoiceResultReviewView(result: res, onDone: { dismiss() }, onDiscard: { dismiss() })
            }
            .task {
                await startRecording()
            }
        }
        .interactiveDismissDisabled(isUploading)
    }

    private var isRecording: Bool {
        if case .recording = recorder.state { return true }
        return false
    }

    private var statusLabel: String {
        switch recorder.state {
        case .idle: return "Preparing…"
        case .requestingPermission: return "Requesting microphone access…"
        case .recording: return "Recording. Tap Stop when done."
        case .stopped: return "Captured."
        case .error(let m): return m
        }
    }

    private func timeString(_ s: TimeInterval) -> String {
        let total = Int(s)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func startRecording() async {
        do {
            try await recorder.start()
            pulse = true
        } catch {
            uploadError = error.localizedDescription
        }
    }

    private func stopAndUpload() async {
        guard let url = recorder.stop() else {
            uploadError = "Recording failed."
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let res = try await APIClient.shared.captureVoice(
                audioURL: url,
                personId: personId,
                context: context
            )
            // Cleanup temp file after upload succeeds
            try? FileManager.default.removeItem(at: url)
            result = res
        } catch {
            uploadError = error.localizedDescription
        }
    }
}

extension VoiceCaptureResult: Hashable {
    static func == (lhs: VoiceCaptureResult, rhs: VoiceCaptureResult) -> Bool {
        lhs.transcript == rhs.transcript && lhs.summary == rhs.summary
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(transcript)
        hasher.combine(summary)
    }
}

#Preview {
    VoiceRecordingView()
}
