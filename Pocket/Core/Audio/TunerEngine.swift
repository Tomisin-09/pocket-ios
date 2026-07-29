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
    /// True while a note has held in tune long enough to be *confirmed* — drives the celebratory UI.
    private(set) var isConfirmed = false
    /// Bumped once each time a note becomes newly confirmed; the view observes it to fire the
    /// success chime + haptic exactly on the lock-on transition.
    private(set) var confirmationID = 0

    /// Reference A used to name pitches — the calibratable A432…446 from Tune Settings. Read live on
    /// the main actor at map time, so changing it takes effect immediately without re-installing the tap.
    var referenceA: Double = 440

    private let engine = AVAudioEngine()
    private let detector = PitchDetector()
    private var smoother = TunerSmoother()
    private var hold = TuneHold(requiredHold: 1.2)
    private var tapInstalled = false
    /// Monotonic time until which detection is frozen (during the post-confirmation chime).
    private var suppressUntil: TimeInterval = 0

    /// Analysis window fed to the detector. Sized so even a low bass string (E1 ≈ 41 Hz) spans a couple
    /// of periods regardless of the hardware's actual tap buffer size (which iOS chooses, not us).
    private static let analysisWindow = 4_096

    // MARK: - Lifecycle

    /// Begin listening. Assumes mic permission is already granted. Idempotent — and guarded against the
    /// double-invocation that the scene-phase churn around the permission dialog can cause.
    func start() {
        guard !isRunning, !tapInstalled else { return }
        AudioPlumbing.configureRecordSession(label: "tuner")

        let input = engine.inputNode
        // Sanity-check the mic route is up before tapping; bail cleanly if not (no crash, just no tune).
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            AudioPlumbing.log.error("tuner: no usable input format (mic unavailable?)")
            AudioPlumbing.configurePlaybackSession(label: "tuner")
            return
        }
        let detector = self.detector                       // value type → safe to capture
        let accumulator = SampleAccumulator(capacity: Self.analysisWindow)

        // `format: nil` installs the tap using the node's **own** output format, so there's no chance
        // of a format/sample-rate mismatch assertion. The real sample rate is read from each buffer.
        //
        // The closure is explicitly **`@Sendable`**. `AVAudioNodeTapBlock` is a legacy, non-Sendable
        // type, so a closure passed from this `@MainActor` method would otherwise inherit main-actor
        // isolation — and iOS 18 / Swift 6 inserts an executor assertion at its entry that **traps**
        // (SIGTRAP) when AVFAudio calls it on the realtime audio thread. `@Sendable` forces it
        // non-isolated; it touches `self` only via the `Task { @MainActor }` hop below.
        input.installTap(onBus: 0, bufferSize: 2_048, format: nil) { @Sendable [weak self] buffer, _ in
            let sampleRate = buffer.format.sampleRate
            guard sampleRate > 0, let mono = buffer.monoSamples() else { return }
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
        hold.reset()
        suppressUntil = 0
        reading = nil
        isConfirmed = false
        isRunning = false
    }

    /// Freeze pitch detection for the next `seconds` — used while the view sounds a **reference tone**
    /// through the shared `ToneEngine`, so the tone bleeding back into the mic isn't read as a played
    /// string. The last reading stays on screen and detection resumes automatically. This is the same
    /// mechanism the post-confirmation chime uses; `max` so a longer freeze already in effect wins.
    func suppressDetection(for seconds: TimeInterval) {
        suppressUntil = max(suppressUntil, ProcessInfo.processInfo.systemUptime + seconds)
    }

    // MARK: - Ingest (main actor)

    /// Map a detected frequency (or `nil`) to a smoothed reading using the current reference pitch, and
    /// publish it. Runs on the main actor — the tap thread only does the pure DSP.
    private func ingest(frequency: Double?) {
        guard isRunning else { return }
        // Runs per audio buffer (~20 Hz), so the hold timer advances even when the smoothed reading
        // value is momentarily unchanged. `systemUptime` is monotonic (immune to clock changes).
        let now = ProcessInfo.processInfo.systemUptime
        // Freeze the reading briefly right after a confirmation, while the success chime sounds — so the
        // chime bleeding into the mic can't knock the note off "confirmed" or retrigger it in a loop.
        // The display stays locked on the note you just nailed for the length of the chime.
        guard now >= suppressUntil else { return }

        // A detected pitch has no key, so the readout spells by the user's preference (ADR 0123) —
        // read per buffer so flipping the Settings picker takes effect without restarting the tuner.
        let spelling = AppSettings.accidentalPreference
        let fresh = frequency.flatMap {
            TunerReading.nearest(toFrequency: $0, referenceA: referenceA, spelling: spelling)
        }
        reading = smoother.ingest(fresh)
        if hold.update(reading: reading, now: now) {
            confirmationID &+= 1
            suppressUntil = now + 0.5
        }
        isConfirmed = hold.isConfirmed
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
