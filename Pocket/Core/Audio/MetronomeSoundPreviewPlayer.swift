import AVFoundation

/// A short **metronome-sound audition** for the Settings timbre picker (ADR 0114): plays a couple of
/// bars of a chosen `ClickTimbre` at a fixed, familiar tempo so you can hear a preset before selecting
/// it. It owns its own tiny `AVAudioEngine` + `ClickVoice` — entirely separate from the live metronome
/// engines — so auditioning never disturbs a running session, and it **auto-stops** after the burst.
///
/// It's an audition, nothing is measured (ADR 0070). The click is fully synthesized (`ClickTimbre`),
/// so there's no file to load — it can start instantly.
@MainActor
@Observable
final class MetronomeSoundPreviewPlayer {
    /// Preview tempo — the metronome's own default launch tempo, a comfortable pulse to judge a sound by.
    static let previewBPM = StandaloneMetronomeEngine.defaultBPM
    /// How many beats an audition plays before stopping itself: two bars of four, first beat accented,
    /// so you hear the accent → beat relationship the way the metronome voices it.
    static let previewBeats = 8

    private let engine = AVAudioEngine()
    private let clickVoice = ClickVoice()
    private var stopTask: Task<Void, Never>?
    /// Lead before the first click so it's scheduled just ahead of the render head, not in the past.
    private let leadSeconds = 0.08

    /// The timbre currently auditioning, or `nil` when silent — drives each row's play/stop glyph.
    private(set) var playingTimbre: ClickTimbre?

    init() { clickVoice.attach(to: engine) }

    /// Whether `timbre` is the one currently sounding.
    func isPlaying(_ timbre: ClickTimbre) -> Bool { playingTimbre == timbre }

    /// Play a short audition of `timbre` at `previewBPM`, then stop itself. Tapping a different timbre
    /// (or the same one again) restarts cleanly — any in-flight audition is cancelled first.
    func play(_ timbre: ClickTimbre) {
        stop()
        AudioPlumbing.configurePlaybackSession(label: "metronome-preview")
        AudioPlumbing.startIfNeeded(engine, label: "metronome-preview")
        clickVoice.loadTimbre(timbre)
        clickVoice.start()
        let beatSeconds = 60.0 / Double(Self.previewBPM)
        for beat in 0..<Self.previewBeats {
            clickVoice.schedule(delay: leadSeconds + Double(beat) * beatSeconds,
                                level: beat % 4 == 0 ? .accent : .beat)
        }
        playingTimbre = timbre
        let runSeconds = leadSeconds + Double(Self.previewBeats) * beatSeconds
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(runSeconds))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    /// Stop the audition and cancel its pending auto-stop. Idempotent — safe to call on disappear.
    func stop() {
        stopTask?.cancel()
        stopTask = nil
        clickVoice.stopAll()
        playingTimbre = nil
    }
}
