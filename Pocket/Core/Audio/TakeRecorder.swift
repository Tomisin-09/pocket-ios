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
    ///
    /// Not `private`: `TakeTrimmer` re-encodes a trimmed span and reads the format from here, so a
    /// trimmed take comes back in exactly the format every other take is in (ADR 0174).
    ///
    /// `nonisolated` and **computed**, because the trimmer runs off the main actor and this class is
    /// `@MainActor`. A stored `static let` would inherit that isolation (unreachable from the
    /// trimmer) and, being a non-`Sendable` dictionary, would not survive Swift 6 strict concurrency
    /// as a `nonisolated` stored property either. A computed property has no shared storage to race
    /// over, so it is safe from anywhere and hands each caller its own copy.
    nonisolated static var settings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

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

    /// Stop capturing and return the take's final duration in seconds (`0` if there was no take).
    ///
    /// `currentTime` is read **before** stopping, because after `stop()` it reports `0`. But it also
    /// reports `0` whenever the *system* stopped the recorder behind our back — a category flip that
    /// removed input from the route, a route change, an interruption — and that zero is what made
    /// `RecordingController` delete files holding real playing (device pass 2026-08-05). So a zero is
    /// never trusted: the true length is read back off the written file instead.
    ///
    /// The guard is `recorder != nil` — "we own an open file" — deliberately **not** the cached
    /// `isRecording`, nor `recorder.isRecording`. Both are *false* in exactly the case this exists
    /// for, so guarding on either would return `0` faster rather than fixing anything.
    @discardableResult
    func stop() -> TimeInterval {
        guard let recorder else { return 0 }
        let url = recorder.url
        let reported = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        ticker?.invalidate()
        ticker = nil
        isRecording = false
        let duration = reported > 0 ? reported : Self.writtenDuration(of: url)
        elapsed = duration
        return duration
    }

    /// The real duration of a written take, read from its header — the fallback for when the recorder
    /// was stopped externally and reports nothing.
    ///
    /// `AVAudioFile` because it is synchronous and header-only; `AVURLAsset.load(.duration)` is async
    /// and `stop()` cannot suspend. Paired with `processingFormat.sampleRate` deliberately — `length`
    /// is in frames of the *processing* format, so using `fileFormat`'s rate would inflate the
    /// duration of a resampled AAC. A file whose header was never finalised won't open, and `0` is
    /// then the honest answer: it holds no playable audio.
    nonisolated static func writtenDuration(of url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url),
              file.processingFormat.sampleRate > 0 else {
            AudioPlumbing.log.error("TakeRecorder: recorder reported no duration and the take won't open")
            return 0
        }
        let seconds = Double(file.length) / file.processingFormat.sampleRate
        // Always a bug, even after the session lease landed — something stopped the recorder without
        // telling us. Dead audio must say why.
        AudioPlumbing.log.error(
            "TakeRecorder: stopped externally — recovered \(seconds, format: .fixed(precision: 2))s from the file")
        return seconds
    }

    private func refreshElapsed() {
        guard let recorder, recorder.isRecording else { return }
        elapsed = recorder.currentTime
    }
}
