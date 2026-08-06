import AVFoundation
import Observation

/// Plays back a **practice take** for relisten (ADR 0069, slice 3). A thin `AVAudioPlayer` wrapper
/// that plays one take at a time — starting a second take stops the first — and publishes which
/// file is playing so a list row can show a play/pause state. Files are the app's own AAC takes in
/// the container, addressed by `fileName` through `RecordingStore`.
@MainActor
@Observable
final class RecordingPlayer {

    /// The take currently playing, or `nil` when stopped. A row is "playing" when this equals its
    /// `fileName`.
    private(set) var playingFileName: String?

    private var player: AVAudioPlayer?
    private var finishDelegate: FinishDelegate?

    func isPlaying(_ fileName: String) -> Bool { playingFileName == fileName }

    /// Toggle a take: start it (stopping any other), or stop it if it's the one already playing.
    func toggle(_ fileName: String) {
        if playingFileName == fileName {
            stop()
            return
        }
        stop()
        // Ensure the shared session is playback-capable — a take may be auditioned from a screen that
        // never armed an engine. Guarded: the Takes sheet opens from screens that hold a record
        // session (a freeform block), and downgrading it here left the *next* take recording under
        // `.playback`, which destroyed it (device pass 2026-08-05).
        AudioPlumbing.ensurePlaybackSession(label: "take-playback")
        guard let url = try? RecordingStore.url(for: fileName),
              let newPlayer = try? AVAudioPlayer(contentsOf: url) else {
            AudioPlumbing.log.error("RecordingPlayer: could not open take \(fileName)")
            return
        }
        let delegate = FinishDelegate { [weak self] in self?.stop() }
        newPlayer.delegate = delegate
        guard newPlayer.play() else {
            AudioPlumbing.log.error("RecordingPlayer: play() refused for \(fileName)")
            return
        }
        player = newPlayer
        finishDelegate = delegate
        playingFileName = fileName
    }

    /// Stop whatever is playing (idempotent). Called on toggle-off, on natural finish, and when the
    /// Takes UI closes.
    func stop() {
        player?.stop()
        player = nil
        finishDelegate = nil
        playingFileName = nil
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
