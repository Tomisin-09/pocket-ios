import Foundation

/// Turns the tuner's per-buffer readings into a **steady** displayed reading (ADR 0115 §6 — "smoothed
/// lightly so the needle settles"). Pure and UI-free, so the settling behaviour is unit-tested rather
/// than eyeballed on a shaking needle.
///
/// Two jobs:
/// - **Ease the cents** while the *same* note keeps sounding (an exponential moving average), so the
///   needle glides instead of twitching on every buffer. A note *change* snaps immediately — you don't
///   want the readout lagging when you move to the next string.
/// - **Ride out brief dropouts.** A plucked string's pitch estimate winks out for a buffer or two as
///   it decays or the detector loses confidence; clearing the readout on the first miss would flicker.
///   The last reading is held for up to `holdFrames` empty buffers before the readout goes blank.
struct TunerSmoother {
    /// Weight given to each *fresh* cents value when the note is unchanged (0…1). Lower is smoother /
    /// laggier; 0.3 settles the needle without feeling sticky.
    var smoothing: Double = 0.3
    /// How many consecutive empty (no-confident-pitch) buffers to keep showing the last reading before
    /// blanking to a "listening" state. At a typical buffer rate this is a fraction of a second.
    var holdFrames: Int = 8

    /// The reading currently shown, or `nil` for the listening state.
    private(set) var current: TunerReading?
    private var missStreak = 0

    /// Explicit init — the synthesized memberwise one would be `private` (the struct has private
    /// state), so callers and tests need this to set `smoothing` / `holdFrames`.
    init(smoothing: Double = 0.3, holdFrames: Int = 8) {
        self.smoothing = smoothing
        self.holdFrames = holdFrames
    }

    /// Fold in the latest reading (`nil` = no confident pitch this buffer) and return what should now
    /// be displayed.
    @discardableResult
    mutating func ingest(_ fresh: TunerReading?) -> TunerReading? {
        guard let fresh else {
            missStreak += 1
            if missStreak >= holdFrames { current = nil }   // held long enough → go quiet
            return current
        }
        missStreak = 0
        if let previous = current, previous.midiNote == fresh.midiNote {
            let easedCents = previous.cents * (1 - smoothing) + fresh.cents * smoothing
            current = TunerReading(midiNote: fresh.midiNote,
                                   noteName: fresh.noteName,
                                   octave: fresh.octave,
                                   cents: easedCents)
        } else {
            current = fresh                                  // new note → snap, don't lag
        }
        return current
    }

    /// Clear all state — used when the tuner stops or resets.
    mutating func reset() {
        current = nil
        missStreak = 0
    }
}
