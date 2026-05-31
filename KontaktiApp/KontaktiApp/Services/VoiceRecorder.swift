import Foundation
import AVFoundation
import Combine

/// Wraps `AVAudioRecorder` for voice-memo capture.
/// Writes to a temp `m4a` (AAC, 44.1 kHz, mono, high quality).
@MainActor
final class VoiceRecorder: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case recording
        case stopped(URL)
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsedSeconds: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var timer: Timer?
    private var startedAt: Date?

    deinit {
        // deinit can run off-main; perform cleanup on main actor
        let r = recorder
        let t = timer
        Task { @MainActor in
            r?.stop()
            t?.invalidate()
        }
    }

    /// Requests microphone permission (iOS 17+ API), configures the audio session,
    /// and begins recording. Throws if permission denied or session setup fails.
    func start() async throws {
        state = .requestingPermission
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    cont.resume(returning: ok)
                }
            }
        }
        guard granted else {
            state = .error("Microphone permission denied. Enable it in Settings.")
            throw NSError(domain: "VoiceRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied."])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memo-\(UUID().uuidString).m4a")
        self.fileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let r = try AVAudioRecorder(url: url, settings: settings)
        r.isMeteringEnabled = true
        guard r.record() else {
            state = .error("Failed to start recording.")
            throw NSError(domain: "VoiceRecorder", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to start recording."])
        }
        self.recorder = r
        self.startedAt = Date()
        self.elapsedSeconds = 0
        self.state = .recording
        startTimer()
    }

    /// Stops recording and returns the file URL.
    @discardableResult
    func stop() -> URL? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let url = fileURL {
            state = .stopped(url)
            return url
        }
        state = .idle
        return nil
    }

    /// Cancels and deletes the file.
    func cancel() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        fileURL = nil
        elapsedSeconds = 0
        state = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startedAt else { return }
                self.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
