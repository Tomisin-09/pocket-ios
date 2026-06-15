import AVFoundation
import Observation

/// Minimal practice playback engine: AVAudioEngine → player → time-pitch
/// (pitch-preserving speed) → mixer. AVFoundation lives here in Core/Audio; the
/// pure math stays in `AudioMath`. See docs/architecture.md and ADR 0001.
///
/// Looping a region and reacting to repeat are layered on later; this is
/// play / pause / seek / rate with a published `currentTime`.
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

    // MARK: - Private

    private func scheduleFromSeek() {
        guard let file else { return }
        let remaining = totalFrames - seekFrame
        guard remaining > 0 else { return }
        generation += 1
        let token = generation
        player.scheduleSegment(file, startingFrame: seekFrame,
                               frameCount: AVAudioFrameCount(remaining), at: nil) { [weak self] in
            Task { @MainActor in self?.handleReachedEnd(token: token) }
        }
        scheduled = true
    }

    private func handleReachedEnd(token: Int) {
        guard token == generation else { return }   // a newer segment superseded this one
        player.stop()
        scheduled = false
        isPlaying = false
        seekFrame = 0
        currentTime = 0
        stopTimer()
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
