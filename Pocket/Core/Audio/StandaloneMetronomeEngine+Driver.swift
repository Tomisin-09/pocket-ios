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
        // Claim the shared session for this run — released by `stop()`, and paired by the transport
        // guards on both (one lease per run). The lease is what stops an *outgoing* run screen
        // deactivating the session an incoming one has just activated (ADR 0129 device pass, bug 1);
        // it is taken before the guard below because the claim holds whatever the category is.
        AudioPlumbing.retainSession()
        // Don't stomp a record-capable session an armed take set up (ADR 0069): the metronome plays
        // fine under `.playAndRecord`, and forcing `.playback` here mid-run would kill the in-flight
        // recording. The guard used to live inline here, on the assumption that `PracticeAudioEngine`
        // configures once at load and so didn't need it; that assumption was wrong, so it now lives
        // in `ensurePlaybackSession` and every producer gets it. The restore to `.playback` after a
        // take ends is still done explicitly by `RecordingController`, not here.
        AudioPlumbing.ensurePlaybackSession(label: "metronome")
    }
}
