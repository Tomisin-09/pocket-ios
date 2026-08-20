import AVFoundation
import Observation

/// Plays back a **practice take** for relisten (ADR 0069, slice 3). A thin `AVAudioPlayer` wrapper
/// that plays one take at a time — starting a second take stops the first — and publishes which
/// file is loaded so a list row can show a play/pause state. Files are the app's own AAC takes in
/// the container, addressed by `fileName` through `RecordingStore`.
///
/// **Two grammars, deliberately.** The takes lists drive this with `toggle` — one gesture, start at
/// the beginning or stop — because a row has room for exactly one control. The take detail screen
/// (ADR 0174) drives it with `play`/`pause`/`resume`/`seek`, because a screen that draws a playhead
/// has somewhere to put a position. Both run through the same loaded-take state, so a take
/// auditioned from a row and then opened is still the take that is playing.
///
/// **`position` is a per-tick value and ADR 0153 governs who may read it.** Only a view that draws a
/// moving playhead may take an observation dependency on it; anything carrying sheets, derived
/// collections or sibling controls must not, or it re-executes its body at the ticker's rate.
@MainActor
@Observable
final class RecordingPlayer {

    /// The take currently **loaded** — playing, paused, or finished but still cued. A row is
    /// "playing" only when this is its file *and* the take is running, which is what `isPlaying`
    /// answers; this one is what the detail screen binds its transport to.
    private(set) var currentFileName: String?

    /// Whether the loaded take is advancing. False while paused, and false once a take reaches its
    /// end — the take stays loaded there so the playhead can rest at the end rather than snapping
    /// back to a zero nobody asked for.
    private(set) var isRunning = false

    /// Playback position in seconds within the loaded take, refreshed ~20 Hz while running and left
    /// where it landed when paused, sought or finished. **ADR 0153:** read this only from a leaf
    /// that draws the playhead.
    private(set) var position: TimeInterval = 0

    /// The loaded take's full length in seconds, read off the opened file — `0` when nothing is
    /// loaded. Taken from the file rather than the `Recording` row so the scrubber is scaled by the
    /// audio that actually exists, which is the thing a trim has just changed.
    private(set) var duration: TimeInterval = 0

    /// How often the position is refreshed. Twenty times a second reads as smooth for a playhead on
    /// a strip this size, and is a sixth of the rate `DisplayLinkTicker` drives the song waveform at
    /// — a take has no beat grid or page-mode to keep in step, so it doesn't need the frames.
    private static let tickInterval: TimeInterval = 0.05

    private var player: AVAudioPlayer?
    private var finishDelegate: FinishDelegate?
    private var ticker: Timer?

    /// Stop at this position instead of at the end of the file — the trim preview, which auditions
    /// the span you are about to keep. `nil` plays to the end.
    private var playUntil: TimeInterval?

    /// Whether `fileName` is the loaded take *and* it is advancing. What a row's play/pause glyph
    /// binds to.
    func isPlaying(_ fileName: String) -> Bool { currentFileName == fileName && isRunning }

    /// Whether `fileName` is the loaded take at all, running or not.
    func isLoaded(_ fileName: String) -> Bool { currentFileName == fileName }

    /// Toggle a take from a list row: start it at the beginning (stopping any other), or stop it if
    /// it is the one already playing. Unchanged from the original single-control grammar — a paused
    /// or finished take is *not* playing, so it restarts, which is what a row with one button should
    /// do.
    func toggle(_ fileName: String) {
        if isPlaying(fileName) {
            stop()
            return
        }
        play(fileName)
    }

    /// Load `fileName` and start it at `from`, optionally stopping early at `until` (the trim
    /// preview). Stops whatever was playing first — one take at a time.
    ///
    /// Returns `false` if the take could not be opened or refused to play, having logged why;
    /// failures are surfaced, not swallowed, like the rest of `Core/Audio`.
    @discardableResult
    func play(_ fileName: String, from start: TimeInterval = 0, until end: TimeInterval? = nil) -> Bool {
        stop()
        // Ensure the shared session is playback-capable — a take may be auditioned from a screen that
        // never armed an engine. Guarded: the Takes sheet opens from screens that hold a record
        // session (a freeform block), and downgrading it here left the *next* take recording under
        // `.playback`, which destroyed it (device pass 2026-08-05).
        AudioPlumbing.ensurePlaybackSession(label: "take-playback")
        guard let url = try? RecordingStore.url(for: fileName),
              let newPlayer = try? AVAudioPlayer(contentsOf: url) else {
            AudioPlumbing.log.error("RecordingPlayer: could not open take \(fileName)")
            return false
        }
        let delegate = FinishDelegate { [weak self] in self?.finish() }
        newPlayer.delegate = delegate
        newPlayer.currentTime = Self.clamped(start, to: newPlayer.duration)
        guard newPlayer.play() else {
            AudioPlumbing.log.error("RecordingPlayer: play() refused for \(fileName)")
            return false
        }
        player = newPlayer
        finishDelegate = delegate
        currentFileName = fileName
        duration = newPlayer.duration
        position = newPlayer.currentTime
        playUntil = end.map { Self.clamped($0, to: newPlayer.duration) }
        isRunning = true
        startTicker()
        return true
    }

    /// Hold the loaded take where it is. Idempotent, and a no-op when nothing is loaded.
    func pause() {
        guard let player, isRunning else { return }
        player.pause()
        position = player.currentTime
        isRunning = false
        stopTicker()
    }

    /// Resume the loaded take from where `pause` (or a seek) left it. A take parked at its very end
    /// starts again from the beginning, rather than playing nothing and looking broken.
    @discardableResult
    func resume() -> Bool {
        guard let player, !isRunning else { return false }
        if player.currentTime >= (playUntil ?? player.duration) - 0.05 {
            player.currentTime = 0
        }
        guard player.play() else {
            AudioPlumbing.log.error("RecordingPlayer: play() refused on resume")
            return false
        }
        position = player.currentTime
        isRunning = true
        startTicker()
        return true
    }

    /// Move the loaded take's playhead, clamped into the file. Works whether the take is running or
    /// paused — scrubbing a paused take moves the playhead and leaves it paused, which is what a
    /// drag on a stopped scrubber should do.
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let target = Self.clamped(time, to: player.duration)
        player.currentTime = target
        position = target
    }

    /// The span the trim preview should stop at, or `nil` to play to the end. Set while a trim is
    /// being adjusted so the next play auditions the keep-span; cleared when trim mode closes.
    func limitPlayback(until end: TimeInterval?) {
        playUntil = end.map { Self.clamped($0, to: duration) }
    }

    /// Stop whatever is playing and unload it (idempotent). Called on toggle-off, when a takes UI
    /// closes, and before anything that rewrites the file underneath the player.
    func stop() {
        stopTicker()
        player?.stop()
        player = nil
        finishDelegate = nil
        currentFileName = nil
        isRunning = false
        position = 0
        duration = 0
        playUntil = nil
    }

    /// Clamp `time` into `0...limit`, tolerating the degenerate zero-length file.
    private static func clamped(_ time: TimeInterval, to limit: TimeInterval) -> TimeInterval {
        guard limit > 0 else { return 0 }
        return min(max(time, 0), limit)
    }

    /// The take ran out — either the file ended or it reached the preview limit. The take stays
    /// **loaded** with its playhead at the stopping point: a row reads this as not-playing and
    /// restarts on the next tap, while the detail screen keeps a playhead to resume from.
    private func finish() {
        guard let player else { return }
        player.pause()
        position = playUntil ?? player.duration
        isRunning = false
        stopTicker()
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    /// Publish the position, and enforce the preview limit. `AVAudioPlayer` has no "stop at" of its
    /// own, so the limit is checked here — at 20 Hz it overshoots by at most a twentieth of a second,
    /// which is inaudible against a span you are choosing by eye.
    private func tick() {
        guard let player, isRunning else { return }
        if let playUntil, player.currentTime >= playUntil {
            finish()
            return
        }
        position = player.currentTime
    }

    /// Bridges `AVAudioPlayerDelegate` (a `nonisolated` NSObject protocol) back to the main actor.
    /// The callback is delivered on the run loop the player started on — the main thread here — so
    /// `assumeIsolated` is safe, matching `NowPlayingController`.
    private final class FinishDelegate: NSObject, AVAudioPlayerDelegate {
        let onFinish: @MainActor () -> Void
        init(onFinish: @escaping @MainActor () -> Void) { self.onFinish = onFinish }
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            let onFinish = self.onFinish   // capture the handler, not self, across the isolation hop
            MainActor.assumeIsolated { onFinish() }
        }
    }
}
