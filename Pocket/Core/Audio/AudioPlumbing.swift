import AVFoundation
import os

/// Shared AVAudioSession / engine-start plumbing for the app's audio engines
/// (`PracticeAudioEngine`, `StandaloneMetronomeEngine`, `ToneEngine`, and the
/// recording path) — one place for the category/activation dance they each need
/// before sound can come out.
///
/// Failures are **logged, not swallowed** (backlog robustness item, audit
/// 2026-07-05): for an audio-first app a dead session means silent no-sound, so
/// at minimum the console must say why. The callers stay non-throwing — playback
/// simply won't start, and the run-screen load paths surface their own failure
/// state to the user.
enum AudioPlumbing {

    /// Audio subsystem logger — also used by the practice/loop-run load paths to
    /// report bookmark-resolution and file-load failures.
    static let log = Logger(subsystem: "click.decooperations.pocket", category: "audio")

    /// Set the shared session to `.playback` and activate it, logging on failure.
    /// Also the **restore** path after a recording take ends — flips the session
    /// back off `.playAndRecord` so the metronome/playback graph is unaffected
    /// when nothing is armed (ADR 0069 §3).
    static func configurePlaybackSession(label: StaticString) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            log.error("\(label): audio session setup failed: \(error.localizedDescription)")
        }
    }

    /// Record-capable session config, applied **only while a take is armed** (ADR
    /// 0069 §3) — never a global flip, so the non-recording behaviour of both
    /// engines is unchanged. The option set is the copyright/quality guardrail:
    ///
    /// - `.playAndRecord` — the mic must be capturable while the loop/song plays.
    /// - `.defaultToSpeaker` — `.playAndRecord` otherwise routes output to the
    ///   quiet earpiece; force the loud bottom speaker.
    /// - `.allowBluetoothA2DP` **and deliberately not `.allowBluetooth`** — with
    ///   HFP allowed, iOS collapses a connected Bluetooth route to 8/16 kHz mono
    ///   "phone-call" quality the moment it wants the earbud mic, wrecking the
    ///   backing track the user hears. A2DP-only keeps output high-quality and
    ///   lets input fall back to the built-in mic — which is what we want anyway:
    ///   the guitar is in the room, not the earbuds (ADR 0069, feasibility doc).
    ///
    /// Mode stays `.default` — never `.voiceChat`/`.measurement` voice-processing,
    /// which applies speech-tuned AGC/AEC that mangles instrument tone (ADR 0069 §2).
    static func configureRecordSession(label: StaticString) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            log.error("\(label): record session setup failed: \(error.localizedDescription)")
        }
    }

    /// Assert a **playback-capable** session without downgrading a record-capable one — what every
    /// producer should call on start, rather than `configurePlaybackSession` directly.
    ///
    /// The guard is the whole point. Forcing `.playback` while a take is rolling removes input from
    /// the route, the system stops the `AVAudioRecorder`, and `currentTime` then reports `0` — which
    /// `RecordingController` reads as an accidental half-second tap and **deletes the file**. That is
    /// how real playing was destroyed (device pass 2026-08-05); the guard existed in
    /// `StandaloneMetronomeEngine`, which is the only reason the metronome never caused it.
    ///
    /// A `.playAndRecord` session is still made **active**: skipping the call entirely would leave a
    /// producer rendering into a session somebody else deactivated, which is silence with no error
    /// anywhere. The restore to `.playback` is done explicitly by whoever armed the take
    /// (`RecordingController`, `TunerEngine`), never as a side effect here.
    static func ensurePlaybackSession(label: StaticString) {
        let session = AVAudioSession.sharedInstance()
        guard session.category == .playAndRecord else {
            return configurePlaybackSession(label: label)
        }
        do { try session.setActive(true) } catch {
            log.error("\(label): audio session activation failed: \(error.localizedDescription)")
        }
    }

    /// The record-capable mirror: a no-op when `.playAndRecord` is already in force, so it can be
    /// asserted before **every** take without ever being the mid-flight category flip ADR 0069
    /// removed. Assert this rather than tracking whether some screen already configured the session —
    /// a flag can be right while the session has since been downgraded underneath it.
    static func ensureRecordSession(label: StaticString) {
        guard AVAudioSession.sharedInstance().category != .playAndRecord else { return }
        configureRecordSession(label: label)
    }

    /// Start `engine` if it isn't already running, logging on failure.
    static func startIfNeeded(_ engine: AVAudioEngine, label: StaticString) {
        guard !engine.isRunning else { return }
        do { try engine.start() } catch {
            log.error("\(label): engine failed to start: \(error.localizedDescription)")
        }
    }

    // MARK: - Session lease (who is allowed to deactivate)

    /// Live lease count for the shared session. `@MainActor` because every audio producer in the app
    /// is main-actor isolated, so the counter needs no lock.
    @MainActor private static var lease = AudioSessionLease()

    /// Register that a producer has begun rendering and needs the shared session **active**. Paired
    /// with exactly one `releaseSession` when it stops.
    @MainActor static func retainSession() { lease.retain() }

    /// Give up this producer's claim on the shared session, deactivating it only once **nobody else**
    /// holds one — `.notifyOthersOnDeactivation` so another app's music can resume.
    ///
    /// The counting is the whole point (ADR 0129 device pass, bug 1). `setActive(false)` is
    /// process-global, and two producers legitimately overlap for a moment when one run screen hands
    /// over to the next: SwiftUI builds and *starts* the incoming block's engine before it tears down
    /// the outgoing one, so an unconditional deactivate in the outgoing `stop()` silenced the engine
    /// that had just started. Its `AVAudioPlayerNode` then never rendered, `renderSampleTime()` stayed
    /// `nil`, and the run sat on "Counting in 4" forever with a perfectly responsive UI.
    @MainActor static func releaseSession(label: StaticString) {
        guard lease.release() else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("\(label): audio session deactivation failed: \(error.localizedDescription)")
        }
    }

    /// Test seam — how many producers currently hold the session.
    @MainActor static var sessionHolders: Int { lease.holders }
}

/// A **reference count** over the shared audio session's active state: how many producers currently
/// need it. Pure and Foundation-only so the "last one out deactivates" rule is unit-tested per
/// AGENTS.md — it is exactly the kind of bookkeeping that breaks silently (the failure mode is
/// no sound, with no error anywhere).
struct AudioSessionLease {
    private(set) var holders = 0

    mutating func retain() { holders += 1 }

    /// Release one holder. Returns `true` only when that was the **last** one, i.e. the session may
    /// now be deactivated. An unbalanced extra release is a no-op rather than a deactivation — a
    /// double-`stop()` must never pull the session out from under a producer that is still playing.
    @discardableResult
    mutating func release() -> Bool {
        guard holders > 0 else { return false }
        holders -= 1
        return holders == 0
    }
}

/// **One producer's** claim on the shared session, idempotent in both directions — for an engine
/// whose start and stop aren't already paired by a transport state (`PracticeAudioEngine` can be
/// loaded repeatedly and stopped repeatedly). Taking twice leases once; giving twice releases once.
@MainActor
struct AudioSessionClaim {
    private var held = false

    mutating func take() {
        guard !held else { return }
        held = true
        AudioPlumbing.retainSession()
    }

    mutating func give(label: StaticString) {
        guard held else { return }
        held = false
        AudioPlumbing.releaseSession(label: label)
    }
}
