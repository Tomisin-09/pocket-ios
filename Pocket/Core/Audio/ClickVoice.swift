import AVFoundation

/// One metronome "voice": an `AVAudioPlayerNode` wired straight to a host engine's
/// main mixer — deliberately **not** through the time-pitch unit, so clicks always
/// sound at real-time pitch and rate no matter the song's playback speed — plus two
/// short synthesized click buffers (an accented downbeat and a plain beat) built once
/// and reused. Shared by the in-song metronome (`PracticeAudioEngine`) and the
/// standalone tool (ADR 0026). The pure timing math lives in `MetronomeSchedule`; this
/// is only the audio plumbing.
///
/// Scheduling is expressed as a real-time **delay from now** and resolved against the
/// click node's *own* sample clock, so it stays self-consistent across stop/start
/// (a flush on rate/seek/loop change resets the node timeline and the caller refills).
@MainActor
final class ClickVoice {

    // The click-level enum (`ClickLevel`) now lives with the timbre synthesis in `ClickTimbre.swift`.

    private let player = AVAudioPlayerNode()
    private let sampleRate: Double
    /// The voiced timbre the three buffers were built from (ADR 0114). Reloaded at playback start so
    /// a Settings change takes effect the next time the click sounds.
    private var timbre: ClickTimbre = .default
    private var accent: AVAudioPCMBuffer?
    private var beat: AVAudioPCMBuffer?
    private var subdivision: AVAudioPCMBuffer?

    init(sampleRate: Double = 44_100) {
        self.sampleRate = sampleRate
    }

    /// Attach to `engine` and connect to the main mixer (bypassing any time-pitch).
    /// Builds the click buffers for the user's chosen timbre. Call once after the host engine is
    /// constructed.
    func attach(to engine: AVAudioEngine) {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        loadTimbre(AppSettings.clickTimbre)
    }

    /// (Re)build the three click buffers for `newTimbre` (ADR 0114). Cheap — three ~20–50 ms buffers —
    /// so callers invoke it at playback start (passing `AppSettings.clickTimbre`) to pick up a Settings
    /// change on the next play. No-op when the timbre is unchanged and the buffers already exist, so
    /// re-arming mid-play never rebuilds. The two hosting engines each own a `ClickVoice`, so routing
    /// the choice through here at start keeps the in-song click and the standalone tool in sync.
    func loadTimbre(_ newTimbre: ClickTimbre) {
        guard newTimbre != timbre || accent == nil else { return }
        timbre = newTimbre
        accent = Self.buffer(from: newTimbre.samples(for: .accent, sampleRate: sampleRate), sampleRate: sampleRate)
        beat = Self.buffer(from: newTimbre.samples(for: .beat, sampleRate: sampleRate), sampleRate: sampleRate)
        subdivision = Self.buffer(from: newTimbre.samples(for: .subdivision, sampleRate: sampleRate),
                                  sampleRate: sampleRate)
    }

    private func buffer(for level: ClickLevel) -> AVAudioPCMBuffer? {
        switch level {
        case .accent: return accent
        case .beat: return beat
        case .subdivision: return subdivision
        }
    }

    /// Begin rendering so scheduled clicks sound. Call after the host engine is running
    /// (and again after a `stopAll` flush, before refilling).
    func start() {
        guard !player.isPlaying else { return }
        player.play()
    }

    /// Queue a click `delay` real-seconds from now, on the node's own clock.
    func schedule(delay: TimeInterval, level: ClickLevel) {
        guard let buffer = buffer(for: level) else { return }
        player.scheduleBuffer(buffer, at: playTime(after: delay), options: [], completionHandler: nil)
    }

    /// The voice's sample rate — the conversion factor for absolute-time scheduling.
    var clockSampleRate: Double { sampleRate }

    /// The player's current render position in frames on its own timeline, or `nil` before
    /// it has rendered. The anchor the standalone metronome locks its beat grid to, so
    /// every click lands at an exact sample position and the tempo can't wander (ADR 0043).
    func renderSampleTime() -> AVAudioFramePosition? {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return nil }
        return playerTime.sampleTime
    }

    /// Queue a click at an **absolute** sample position on the player's timeline. Unlike
    /// `schedule(delay:)` (which re-reads "now" each call and is right for the song-locked
    /// click), this pins every beat to a fixed sample grid, so a song-less metronome stays
    /// dead steady regardless of timer jitter.
    func schedule(atSampleTime sampleTime: AVAudioFramePosition, level: ClickLevel) {
        guard let buffer = buffer(for: level) else { return }
        player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: sampleTime, atRate: sampleRate),
                              options: [], completionHandler: nil)
    }

    /// Cancel every queued click and silence the voice (pause / seek / rate change /
    /// loop wrap / screen exit). Restart with `start()` before scheduling again.
    func stopAll() {
        player.stop()
    }

    // MARK: - Private

    /// An absolute time `delay` seconds ahead on the player's own sample timeline.
    /// Before the node has rendered (no `lastRenderTime`), schedule relative to 0.
    private func playTime(after delay: TimeInterval) -> AVAudioTime {
        let offset = AVAudioFramePosition(delay * sampleRate)
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return AVAudioTime(sampleTime: offset, atRate: sampleRate)
        }
        return AVAudioTime(sampleTime: playerTime.sampleTime + offset, atRate: sampleRate)
    }

    /// Wrap a mono float sample array (synthesized by `ClickTimbre`) in a PCM buffer ready to
    /// schedule. The click *voicing* is the pure `ClickTimbre` synthesis; this is only the
    /// AVFoundation packaging.
    private static func buffer(from samples: [Float], sampleRate: Double) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { channel.update(from: base, count: samples.count) }
        }
        return buffer
    }
}
