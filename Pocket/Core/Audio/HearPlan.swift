import Foundation

/// The **pure scheduling math behind `ToneEngine`/`HearSequencer`** (ADR 0097). Turning an ordered note
/// list into timed note-on/note-off events is deterministic arithmetic — no audio, no engine — so it
/// lives here, Foundation-only, and is exhaustively unit-testable. `HearSequencer` executes the plan
/// against the sampler; this decides *what sounds when*.
enum HearPlan {

    /// One scheduled note: which MIDI pitch, when it onsets, and when it releases — both measured in
    /// seconds from the start of the preview.
    struct Event: Equatable {
        let midi: UInt8
        let onset: TimeInterval
        /// Absolute release time (`onset + duration`), so lateness never accumulates: each deadline is
        /// computed from the start, not from the previous event.
        let offset: TimeInterval
    }

    /// Turn an ordered note list into timed events. `stride` is the gap between successive **onsets**
    /// (0 = block chord — every note onsets at 0 and rings together); `duration` is how long each note
    /// sustains. A `nil` entry is a **rest**: it consumes its index slot (so later notes keep their
    /// place in the walk) but emits no event. Notes are clamped into MIDI range.
    static func events(notes: [Int?], stride: TimeInterval, duration: TimeInterval) -> [Event] {
        notes.enumerated().compactMap { index, note in
            guard let note else { return nil }
            let onset = Double(index) * stride
            return Event(midi: UInt8(clamping: note), onset: onset, offset: onset + duration)
        }
    }

    /// Whether the line plays **monophonically** — each onset first silences whatever's ringing, so at
    /// most one voice sounds. True exactly when notes are spaced (a melodic line, `stride > 0`); a block
    /// chord (`stride == 0`) is polyphonic. Mono playback makes a long run immune to voice pile-up (the
    /// extended-pentatonic diagonal was dropping out on the return, ADR 0097 S3).
    static func isMonophonic(stride: TimeInterval) -> Bool { stride > 0 }
}
