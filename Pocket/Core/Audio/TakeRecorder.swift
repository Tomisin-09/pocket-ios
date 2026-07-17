import AVFoundation
import Observation

/// Captures a **practice take** — the microphone only — to an AAC file (ADR 0069). Built on
/// `AVAudioRecorder` rather than tapping `PracticeAudioEngine`'s graph, so the playback/metronome
/// engines are unchanged while a take is armed (ADR 0069 §3): the recorder captures the mic input,
/// the practice engine keeps playing the loop/song out, and the two never share a node. The app
/// therefore never renders its own playback into the file — any backing track can only couple in
/// *acoustically* (speaker → air → mic), which is the whole basis of the route-not-DSP isolation
/// story (`RecordingRoute`).
///
/// The caller is responsible for the preconditions: mic permission granted (`MicPermission`) and the
/// record-capable session armed (`AudioPlumbing.configureRecordSession`). This type just drives the
/// recorder and publishes `isRecording` / `elapsed` for the UI.
@MainActor
@Observable
final class TakeRecorder {

    /// Whether a take is currently being captured.
    private(set) var isRecording = false

    /// Seconds captured so far — refreshed ~10 Hz for a live timer; frozen at the final duration
    /// after `stop()`.
    private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var ticker: Timer?

    /// AAC in an `.m4a` container, **mono**, 44.1 kHz — the ADR's "encoded AAC (not raw PCM —
    /// storage)". Mono because a take is a single guitar/room mic; it halves the file versus stereo
    /// for no meaningful loss on one source (~1 MB/min, per the feasibility sizing).
    private static let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    /// Begin capturing to `url`. Returns `false` (and logs) if the recorder can't start — failures
    /// are surfaced, not swallowed, matching the rest of `Core/Audio` (dead audio must say why).
    @discardableResult
    func start(to url: URL) -> Bool {
        guard !isRecording else { return true }
        do {
            let recorder = try AVAudioRecorder(url: url, settings: Self.settings)
            guard recorder.record() else {
                AudioPlumbing.log.error("TakeRecorder: record() refused to start")
                return false
            }
            self.recorder = recorder
            isRecording = true
            elapsed = 0
            ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshElapsed() }
            }
            return true
        } catch {
            AudioPlumbing.log.error("TakeRecorder: could not start: \(error.localizedDescription)")
            return false
        }
    }

    /// Stop capturing and return the take's final duration in seconds (`0` if not recording).
    /// Reads `currentTime` **before** stopping — after `stop()` it reports `0`.
    @discardableResult
    func stop() -> TimeInterval {
        guard isRecording, let recorder else { return 0 }
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        ticker?.invalidate()
        ticker = nil
        isRecording = false
        elapsed = duration
        return duration
    }

    private func refreshElapsed() {
        guard let recorder, recorder.isRecording else { return }
        elapsed = recorder.currentTime
    }
}
