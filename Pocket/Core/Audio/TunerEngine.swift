import AVFoundation
import Observation

/// The tuner's **live microphone** engine (ADR 0115). Owns its own small `AVAudioEngine`, installs a
/// tap on the input node, runs each buffer through the pure `PitchDetector` off the main thread, and
/// publishes a `TunerReading?` the view observes. Self-contained like `MetronomeSoundPreviewPlayer` —
/// it does **not** share nodes with `PracticeAudioEngine`, so opening the tuner never disturbs (and is
/// never disturbed by) a live loop or song.
///
/// This is the app's **first live input tap** — the recording path (`TakeRecorder`) writes the mic to
/// a file and never sees live PCM. So the mic-hygiene contract is strict: `stop()` removes the tap,
/// stops the engine, and restores the playback session, and the view is responsible for calling it on
/// disappear / backgrounding so the mic is never held open behind the user's back.
///
/// The caller owns the preconditions (mirroring `TakeRecorder`): mic permission granted
/// (`MicPermission`) before `start()`. Nothing here is measured or graded (ADR 0070) — it reports pitch.
@MainActor
@Observable
final class TunerEngine {

    /// The current, smoothed reading — or `nil` while listening (silence / no confident pitch).
    private(set) var reading: TunerReading?
    /// Whether the tap is live.
    private(set) var isRunning = false

    /// Reference A used to name pitches — the calibratable A432…446 from Tune Settings. Read live on
    /// the main actor at map time, so changing it takes effect immediately without re-installing the tap.
    var referenceA: Double = 440

    private let engine = AVAudioEngine()
    private let detector = PitchDetector()
    private var smoother = TunerSmoother()
    private var tapInstalled = false

    /// Analysis window fed to the detector. Sized so even a low bass string (E1 ≈ 41 Hz) spans a couple
    /// of periods regardless of the hardware's actual tap buffer size (which iOS chooses, not us).
    private static let analysisWindow = 4_096

    // MARK: - Lifecycle

    /// Begin listening. Assumes mic permission is already granted. Idempotent.
    func start() {
        guard !isRunning else { return }
        AudioPlumbing.configureRecordSession(label: "tuner")

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            AudioPlumbing.log.error("tuner: no usable input format (mic unavailable?)")
            AudioPlumbing.configurePlaybackSession(label: "tuner")
            return
        }
        let sampleRate = format.sampleRate
        let detector = self.detector                       // value type → safe to capture
        let accumulator = SampleAccumulator(capacity: Self.analysisWindow)

        input.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            guard let mono = buffer.monoSamples() else { return }
            accumulator.append(mono)
            guard let window = accumulator.window() else { return }   // nil until first full window
            let frequency = detector.detect(window, sampleRate: sampleRate)
            Task { @MainActor in self?.ingest(frequency: frequency) }
        }
        tapInstalled = true

        AudioPlumbing.startIfNeeded(engine, label: "tuner")
        isRunning = true
    }

    /// Stop listening: remove the tap, stop the engine, restore the playback session, and blank the
    /// readout. Idempotent — safe to call on `.onDisappear` and scene-phase changes.
    func stop() {
        guard isRunning else { return }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        AudioPlumbing.configurePlaybackSession(label: "tuner")   // flip back off .playAndRecord
        smoother.reset()
        reading = nil
        isRunning = false
    }

    // MARK: - Ingest (main actor)

    /// Map a detected frequency (or `nil`) to a smoothed reading using the current reference pitch, and
    /// publish it. Runs on the main actor — the tap thread only does the pure DSP.
    private func ingest(frequency: Double?) {
        guard isRunning else { return }
        let fresh = frequency.flatMap { TunerReading.nearest(toFrequency: $0, referenceA: referenceA) }
        reading = smoother.ingest(fresh)
    }
}

/// A rolling window of the most recent samples, fed from the audio tap. Kept at exactly `capacity`
/// once filled, so the detector always sees a full analysis window even when the hardware hands us
/// small buffers.
///
/// `@unchecked Sendable`: the tap block that owns this instance is invoked serially on a single audio
/// render thread, so its mutations never overlap. It is not touched from anywhere else.
private final class SampleAccumulator: @unchecked Sendable {
    private var storage: [Float] = []
    private let capacity: Int
    private var filled = false

    init(capacity: Int) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    func append(_ samples: [Float]) {
        storage.append(contentsOf: samples)
        if storage.count >= capacity {
            if storage.count > capacity { storage.removeFirst(storage.count - capacity) }
            filled = true
        }
    }

    /// The current full window, or `nil` until `capacity` samples have accumulated.
    func window() -> [Float]? { filled ? storage : nil }
}

private extension AVAudioPCMBuffer {
    /// Copy the buffer's first channel to a plain `[Float]`, valid past the tap callback. Returns `nil`
    /// for a non-float or empty buffer. One channel is enough — a tuner reads a single instrument, and
    /// the input is mono anyway.
    func monoSamples() -> [Float]? {
        guard let channels = floatChannelData, frameLength > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: channels[0], count: Int(frameLength)))
    }
}
