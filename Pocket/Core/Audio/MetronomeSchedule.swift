import Foundation

/// Pure, UI-free metronome click scheduling (ADR 0026). Decides *which* beats to
/// fire and *how far ahead* of now each one sounds, so the AVFoundation layer only
/// has to turn a real-time delay into a sample time on the audio clock. Kept free of
/// AVFoundation so the timing math — the kind that breaks silently without coverage —
/// is exhaustively unit-tested (AGENTS.md).
///
/// The in-song click rides the song's `BeatGrid`: a beat lives at a fixed *source*
/// time, but the song is heard through the time-pitch unit at a playback `rate`, so
/// the beat's real-time arrival is `(beatTime − now) / rate`. That single divide is
/// why the click follows playback speed — at 0.5× the spacing doubles in real time
/// (the click slows with the track), at 2× it halves.
enum MetronomeSchedule {

    /// One click to fire: the beat's source time (so the caller can dedup across
    /// refreshes), how long from the reference "now" (real seconds) it sounds, and
    /// whether it lands on a bar's downbeat (the accented click).
    struct Click: Equatable {
        let time: TimeInterval
        let delay: TimeInterval
        let isDownbeat: Bool
    }

    /// The in-song clicks due within the next `horizon` real seconds.
    ///
    /// `beats` is the song's grid as ascending (source seconds, isDownbeat) pairs —
    /// `BeatGrid.beats(...)` mapped through the song duration. Only beats strictly
    /// ahead of `currentSourceTime` (by more than `epsilon`, so a beat level with the
    /// playhead isn't re-fired on the next refresh) and within the real-time `horizon`
    /// are returned, ascending by delay. A non-positive `rate` or `horizon` yields no
    /// clicks. Because `beats` is ascending, scanning stops at the first beat past the
    /// horizon.
    static func upcoming(beats: [(time: TimeInterval, isDownbeat: Bool)],
                         currentSourceTime: TimeInterval,
                         rate: Double,
                         horizon: TimeInterval,
                         epsilon: TimeInterval = 1e-4) -> [Click] {
        guard rate > 0, horizon > 0 else { return [] }
        var result: [Click] = []
        for beat in beats {
            let ahead = beat.time - currentSourceTime
            if ahead <= epsilon { continue }      // behind / level with the playhead
            let delay = ahead / rate
            if delay > horizon { break }          // ascending ⇒ nothing further qualifies
            result.append(Click(time: beat.time, delay: delay, isDownbeat: beat.isDownbeat))
        }
        return result
    }
}
