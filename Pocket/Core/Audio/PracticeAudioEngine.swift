import AVFoundation
import Observation

/// Minimal practice playback engine: AVAudioEngine → player → time-pitch
/// (pitch-preserving speed) → mixer. AVFoundation lives here in Core/Audio; the
/// pure math stays in `AudioMath`. See docs/architecture.md, ADRs 0001 & 0006.
///
/// play / pause / seek / rate, plus continuous **region looping** (an active
/// loop wraps back to its start), with a published `currentTime`.
@MainActor
@Observable
final class PracticeAudioEngine {

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()

    private var file: AVAudioFile?
    private var sampleRate: Double = 44_100
    private var totalFrames: AVAudioFramePosition = 0
    private var seekFrame: AVAudioFramePosition = 0
    private var scheduled = false
    /// Invalidates in-flight segment completion handlers across stop/seek so a
    /// stale "reached end" can't reset state for the new segment.
    private var generation = 0
    private var displayTimer: Timer?
    /// When set, playback loops this region (seconds): reaching its end wraps
    /// back to its start. `nil` plays straight through.
    private var loopRegion: (start: TimeInterval, end: TimeInterval)?

    init() {
        engine.attach(player)
        engine.attach(timePitch)
    }

    func load(url: URL) throws {
        let audioFile = try AVAudioFile(forReading: url)
        file = audioFile
        let format = audioFile.processingFormat
        sampleRate = format.sampleRate
        totalFrames = audioFile.length
        duration = AudioMath.framesToSeconds(Int(totalFrames), sampleRate: sampleRate)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        configureSession()
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        guard file != nil else { return }
        startEngineIfNeeded()
        if !scheduled { scheduleFromSeek() }
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player.pause()
        isPlaying = false
        stopTimer()
    }

    /// Move the play position; resumes from `seconds` if it was playing.
    func seek(toSeconds seconds: TimeInterval) {
        let clamped = min(max(0, seconds), duration)
        seekFrame = AVAudioFramePosition(AudioMath.secondsToFrames(clamped, sampleRate: sampleRate))
        let wasPlaying = isPlaying
        generation += 1            // invalidate the in-flight segment's completion
        player.stop()
        scheduled = false
        currentTime = clamped
        if wasPlaying { play() }
    }

    /// Pitch-preserving playback speed (0.25×–2.0×).
    func setRate(_ rate: Double) {
        timePitch.rate = Float(min(2.0, max(0.25, rate)))
    }

    /// Loop a region (seconds) continuously. Takes effect on the next schedule —
    /// callers that want it to start now should follow with `seek(toSeconds:)`.
    func setLoop(start: TimeInterval, end: TimeInterval) {
        loopRegion = (start: start, end: end)
    }

    /// Stop looping; if playing, re-arm from the current position so it plays
    /// straight through to the end instead of stopping at the old loop end.
    func clearLoop() {
        loopRegion = nil
        if isPlaying { seek(toSeconds: currentTime) }
    }

    // MARK: - Private

    private func scheduleFromSeek() {
        guard let file else { return }
        let frameCount = segmentEndFrame() - seekFrame
        guard frameCount > 0 else { return }
        generation += 1
        let token = generation
        // `.dataPlayedBack` fires when the audio has actually been rendered out —
        // the legacy handler is `.dataConsumed`, which fires ~a buffer early (the
        // player reads ahead), making a loop wrap noticeably before its end.
        player.scheduleSegment(file, startingFrame: seekFrame,
                               frameCount: AVAudioFrameCount(frameCount), at: nil,
                               completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.handleReachedEnd(token: token) }
        }
        scheduled = true
    }

    /// Where the current segment ends — the loop end when looping, else the end
    /// of the file.
    private func segmentEndFrame() -> AVAudioFramePosition {
        guard let loopRegion else { return totalFrames }
        let seg = AudioMath.loopSegment(start: loopRegion.start, end: loopRegion.end,
                                        sampleRate: sampleRate, totalFrames: Int(totalFrames))
        return AVAudioFramePosition(seg.startFrame + seg.frameCount)
    }

    private func handleReachedEnd(token: Int) {
        guard token == generation else { return }   // a newer segment superseded this one
        if let loopRegion, isPlaying {
            seek(toSeconds: loopRegion.start)        // wrap to the loop start, keep playing
        } else {
            player.stop()
            scheduled = false
            isPlaying = false
            seekFrame = 0
            currentTime = 0
            stopTimer()
        }
    }

    private func updateCurrentTime() {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return }
        let played = Double(playerTime.sampleTime) / playerTime.sampleRate
        currentTime = min(duration, Double(seekFrame) / sampleRate + max(0, played))
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        try? engine.start()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
    }

    private func startTimer() {
        stopTimer()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateCurrentTime() }
        }
    }

    private func stopTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
}
