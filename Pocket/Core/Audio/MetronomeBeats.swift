import Foundation

/// Pure, UI-free beat-sequence generator for the **standalone** metronome (ADR 0043,
/// slice 1).
///
/// The in-song click rides a song's `BeatGrid` (beats fixed by the recording, phase
/// anchored to where the downbeat falls). The standalone metronome has no song clock,
/// so it *generates* its own grid from first principles: a tempo (`bpm`) and a time
/// signature (`beatsPerBar`) fix the beat interval (`60 / bpm`) and the accent pattern
/// (a downbeat every `beatsPerBar`-th beat). Beat 0 sits at `t = 0`; the sequence runs
/// forward from there, so the caller refreshes a window ahead of "now" exactly as the
/// in-song path does.
///
/// The output — ascending `(time, isDownbeat)` pairs in absolute seconds — drops
/// straight into `MetronomeSchedule.upcoming(beats:…)` at `rate = 1.0` and drives both
/// the audio (via `ClickVoice`) and the on-screen beat indicator from one source, so
/// the two can't drift. Kept Foundation-only so the stepping math — the kind that
/// breaks silently without coverage — is exhaustively unit-tested (AGENTS.md).
enum MetronomeBeats {

    /// Runaway guard: a window asking for more beats than this is a degenerate tempo /
    /// horizon combination, so it yields no beats rather than allocating unboundedly.
    static let maxBeats = 100_000

    /// A single generated beat: its absolute time (seconds from the t=0 start) and
    /// whether it starts a bar (a downbeat — the accented click).
    struct Beat: Equatable {
        let time: TimeInterval
        let isDownbeat: Bool
    }

    /// Every beat landing in the window `[from, through]` (inclusive), ascending.
    ///
    /// Beats step from `t = 0` at `60 / bpm` seconds; every `beatsPerBar`-th beat
    /// counting from beat 0 is a downbeat (beat 0 itself is one). The window lets the
    /// caller refresh just the slice ahead of the playhead instead of regenerating from
    /// zero each tick. `bpm` is a `Double` so a tapped or dialled-in fractional tempo
    /// keeps its precision (rounding to `Int` would drift the grid over a long sitting).
    /// Returns `[]` for a non-positive `bpm`, an empty/inverted window, or when the
    /// window would exceed `maxBeats`. `beatsPerBar` is treated as at least 1.
    static func beats(bpm: Double,
                      beatsPerBar: Int = 4,
                      from start: TimeInterval = 0,
                      through end: TimeInterval) -> [Beat] {
        guard bpm > 0, end >= start else { return [] }
        let interval = 60.0 / bpm
        guard interval > 0 else { return [] }
        let perBar = max(1, beatsPerBar)

        // Integer beat indices k ≥ 0 whose time k·interval lands in [start, end]. A
        // tiny epsilon absorbs float error so a beat sitting exactly on an edge isn't
        // dropped by `floor`/`ceil`.
        let epsilon = interval * 1e-9
        let kMin = max(0, Int(((start - epsilon) / interval).rounded(.up)))
        let kMax = Int(((end + epsilon) / interval).rounded(.down))
        guard kMin <= kMax, kMax - kMin + 1 <= maxBeats else { return [] }

        var result: [Beat] = []
        result.reserveCapacity(kMax - kMin + 1)
        for beatIndex in kMin...kMax {
            let time = Double(beatIndex) * interval
            let isDownbeat = beatIndex % perBar == 0
            result.append(Beat(time: time, isDownbeat: isDownbeat))
        }
        return result
    }

    /// The same sequence shaped as the labelled tuples `MetronomeSchedule.upcoming`
    /// consumes — so the standalone path can hand its generated grid straight to the
    /// shared scheduler without an adapter at the call site.
    static func sequence(bpm: Double,
                         beatsPerBar: Int = 4,
                         from start: TimeInterval = 0,
                         through end: TimeInterval) -> [(time: TimeInterval, isDownbeat: Bool)] {
        beats(bpm: bpm, beatsPerBar: beatsPerBar, from: start, through: end)
            .map { (time: $0.time, isDownbeat: $0.isDownbeat) }
    }
}
