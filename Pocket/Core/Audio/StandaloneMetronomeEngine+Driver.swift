import AVFoundation

/// The standalone metronome's **plumbing** — the `AVAudioEngine` lifecycle, the look-ahead
/// driver timer, and the lock-screen / Control Center push — split out of
/// `StandaloneMetronomeEngine.swift` for file length (like the `+Automator` config split).
/// The transport (`start` / `pause` / `resume` / `stop`) and the beat/grid math stay in the
/// core file; this is the machinery they drive, so these handles are internal, not private.
extension StandaloneMetronomeEngine {

    /// Push the metronome's state to the lock screen / Control Center. Title is the tool,
    /// the secondary line is the live tempo + meter, and the rate freezes the clock when
    /// paused.
    func pushNowPlaying() {
        guard transport != .stopped else { return }
        nowPlaying.update(NowPlayingState(
            title: "Metronome",
            artist: "\(bpm) BPM · \(timeSignature.name)",
            duration: 0,
            elapsedTime: elapsed,
            isPlaying: transport == .playing,
            speed: 1))
    }

    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func startEngineIfNeeded() {
        AudioPlumbing.startIfNeeded(engine, label: "metronome")
    }

    func configureSession() {
        // Don't stomp a record-capable session an armed take set up (ADR 0069): the metronome plays
        // fine under `.playAndRecord`, and forcing `.playback` here mid-run would kill the in-flight
        // recording. Unlike `PracticeAudioEngine` (which configures once at load), this engine
        // reconfigures on every `start()`, so the guard lives here. The restore to `.playback` after
        // a take ends is done explicitly by `RecordingController`, not here.
        guard AVAudioSession.sharedInstance().category != .playAndRecord else { return }
        AudioPlumbing.configurePlaybackSession(label: "metronome")
    }
}
