import Foundation

// MARK: - Heard time (ADR 0140 §3)
//
// Split out of `PracticeAudioEngine.swift` for the 400-line budget, unchanged, to make room for the
// song player's playing-state hook (ADR 0322). Nothing here touches the engine's stored state.

extension PracticeAudioEngine {

    /// Pull a rendered position back to what the ear is hearing, through the stretcher's
    /// rate-dependent latency (ADR 0140 §3). `currentTime` is published in *heard* time, which is why
    /// the metronome needs no offset of its own: `MetronomeSchedule` measures each beat from this
    /// value, so the click and the visual playhead are corrected by the same single subtraction.
    func heard(_ rendered: TimeInterval) -> TimeInterval {
        guard compensatesStretcherLatency else { return max(0, rendered) }
        return AudioMath.heardPlayhead(rendered: rendered, latency: stretcher.latency,
                                       rate: stretcher.rate)
    }

    /// Release always compensates — ADR 0140 closes off exposing the stretcher to the player. The
    /// DEBUG toggle exists only to A/B the correction by ear against the uncorrected build, which is
    /// a far easier judgment than deciding in the absolute whether a click is 93 ms early. Read live
    /// rather than cached so flipping it in Settings takes effect on the next frame.
    private var compensatesStretcherLatency: Bool {
        #if DEBUG
        return AppSettings.compensateStretchLatency
        #else
        return true
        #endif
    }
}
