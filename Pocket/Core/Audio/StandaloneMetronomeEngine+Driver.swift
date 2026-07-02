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
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
    }
}
