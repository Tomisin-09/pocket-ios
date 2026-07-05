import AVFoundation
import os

/// Shared AVAudioSession / engine-start plumbing for the app's two audio engines
/// (`PracticeAudioEngine`, `StandaloneMetronomeEngine`) — one place for the
/// category/activation dance both need before sound can come out.
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
    static func configurePlaybackSession(label: StaticString) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            log.error("\(label): audio session setup failed: \(error.localizedDescription)")
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
