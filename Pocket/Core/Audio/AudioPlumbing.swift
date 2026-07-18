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

    /// Start `engine` if it isn't already running, logging on failure.
    static func startIfNeeded(_ engine: AVAudioEngine, label: StaticString) {
        guard !engine.isRunning else { return }
        do { try engine.start() } catch {
            log.error("\(label): engine failed to start: \(error.localizedDescription)")
        }
    }
}
