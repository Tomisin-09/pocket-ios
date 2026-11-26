import Foundation

// MARK: - An interruption pauses the transport (ADR 0323)
//
// A call, Siri, an alarm or another app's audio stops Red Moon's audio: the session is `.playback`,
// which doesn't mix. The system stops this engine without telling it, so until ADR 0323 `isPlaying`
// stayed true and every transport built on it kept its ■ lit over silence. The output going away
// (headphones pulled out) is handled the same way, as Apple asks of a player (D4). Split out for the 400-line
// budget; the observer and the flag it sets are stored on the engine itself.

extension PracticeAudioEngine {

    /// The engine has been stopped under the transport: pause, so the transport shows ▶, and tell the
    /// owner. Nothing resumes by itself (ADR 0323 D2): the player presses ▶ when their hands are back.
    ///
    /// The pause is the ordinary one, so `onPlayingChange` fires and the song player's practice-log
    /// count stops with it (ADR 0322). An interruption while paused or stopped still marks the session
    /// for reasserting, because the system deactivated it either way.
    func wasInterrupted() {
        sessionNeedsReassert = true
        if isPlaying { pause() }
        onInterrupted?()
    }
}
