import Foundation

/// Pure, UI-free beat-grid geometry (ADR 0022, roadmap item 7).
///
/// Turns a tempo (`bpm`) plus a **downbeat phase anchor** (the seconds at which a
/// bar-1 downbeat lands) into the song-fraction positions of every beat across the
/// song, flagging the bar-start downbeats. BPM alone fixes the beat *interval*; the
/// anchor fixes the *phase*, so a song with lead-in silence still lines its grid up
/// with the music. Kept free of SwiftUI/AVFoundation so the stepping math — the kind
/// that breaks silently without coverage — is exhaustively unit-tested (AGENTS.md).
/// The drawing layer decides how dense a grid it can afford; the snap layer feeds the
/// beat fractions in as candidates alongside markers and loop edges (ADR 0021).
enum BeatGrid {

    /// Runaway guard: a grid denser than this many beats can't be drawn or snapped to
    /// usefully (it would be sub-pixel), so a degenerate tempo just yields no grid.
    static let maxBeats = 10_000

    /// A single beat: its position as a song fraction (0...1) and whether it starts a
    /// bar (a downbeat).
    struct Beat: Equatable {
        let fraction: Double
        let isDownbeat: Bool
    }

    /// Every beat that lands inside the song `[0, duration]`, ascending. Beats step
    /// outward from `downbeat` (seconds) in both directions at `60 / bpm` seconds;
    /// `beatsPerBar` groups them into bars, so every `beatsPerBar`-th beat counting
    /// from the anchor is a downbeat (the anchor itself is one). Returns `[]` for a
    /// non-positive `bpm`/`duration`, or when the grid would exceed `maxBeats`.
    /// `beatsPerBar` is treated as at least 1. `bpm` is a `Double` so a tap-tempo or
    /// metadata tempo keeps its sub-integer precision (ADR 0024) — rounding it to an
    /// `Int` would drift the grid ~1 beat across a multi-minute song.
    static func beats(bpm: Double, duration: TimeInterval, downbeat: TimeInterval,
                      beatsPerBar: Int = 4) -> [Beat] {
        beats(bpm: bpm, duration: duration, anchors: [downbeat], beatsPerBar: beatsPerBar)
    }

    /// The same grid, but **re-anchorable** (ADR 0154). One tempo and one anchor describe a
    /// straight line, and a straight line is wrong for music whose pulse actually moves: phase
    /// error accumulates as ∫(played tempo − stored tempo)·dt away from the anchor, which is why
    /// a click set against a hand-played, unquantised beat locks, slides out, and slides back.
    ///
    /// Extra anchors cut that line into segments. Beats run forward from each anchor at
    /// `60 / bpm` until the next one, so error can never accumulate past the section being
    /// worked on, and **the bar count restarts at every anchor** — an anchor *is* a 1, and a
    /// correction that kept the running bar count would fix the click while breaking the bar
    /// lines. Before the first anchor the grid extrapolates backwards, as it always has.
    ///
    /// **One invariant makes this total: no two beats may be *closer* than half an interval.**
    /// It applies in both places two beats can collide — a segment's last generated beat
    /// approaching the next anchor (dropped; the anchor's own beat wins, or a correction would
    /// audibly double-click at the seam), and two anchors placed almost on top of each other
    /// (the later is discarded). *Closer*, strictly: a beat landing exactly half an interval
    /// before an anchor survives, because that's an eighth-note gap — a legitimate offbeat, not
    /// the stumble the guard is for. Passing one anchor reproduces the single-anchor grid exactly.
    static func beats(bpm: Double, duration: TimeInterval, anchors: [TimeInterval],
                      beatsPerBar: Int = 4) -> [Beat] {
        guard bpm > 0, duration > 0 else { return [] }
        let interval = 60.0 / bpm
        guard interval > 0 else { return [] }
        let perBar = max(1, beatsPerBar)
        // Absorbs float error so a beat sitting exactly on an edge isn't dropped by a comparison.
        let epsilon = interval * 1e-9
        let minGap = interval / 2

        let ordered = collapsed(anchors, closerThan: minGap)
        guard let first = ordered.first else { return [] }
        let shape = Shape(interval: interval, duration: duration, perBar: perBar, epsilon: epsilon)

        // Pre-roll, then forward from each anchor — the only two phases there are.
        guard var result = preRoll(before: first, shape) else { return [] }
        for (position, anchor) in ordered.enumerated() {
            let next = position + 1 < ordered.count ? ordered[position + 1] : nil
            let limit = min(next.map { $0 - minGap } ?? duration, duration)
            guard let segment = segment(from: anchor, upTo: limit, shape,
                                        budget: maxBeats - result.count) else { return [] }
            result.append(contentsOf: segment)
        }
        return result
    }

    /// The grid geometry shared by both phases, so neither has to be handed five loose scalars.
    private struct Shape {
        let interval: TimeInterval
        let duration: TimeInterval
        let perBar: Int
        let epsilon: TimeInterval

        /// True modulo so negative indices (beats before an anchor) group correctly.
        func beat(at time: TimeInterval, index: Int) -> Beat {
            Beat(fraction: (time / duration).clamped(to: 0...1),
                 isDownbeat: ((index % perBar) + perBar) % perBar == 0)
        }
    }

    /// Anchors in time order with near-duplicates removed — two anchors closer than half an
    /// interval can't both be a 1, so the later is dropped rather than emitting two beats on
    /// top of each other.
    private static func collapsed(_ anchors: [TimeInterval],
                                  closerThan minGap: TimeInterval) -> [TimeInterval] {
        anchors.sorted().reduce(into: [TimeInterval]()) { kept, anchor in
            if let last = kept.last, anchor - last < minGap { return }
            kept.append(anchor)
        }
    }

    /// Beats before the first anchor, back to the song start, so lead-in silence still carries a
    /// grid. Collected descending and flipped, so the caller's result stays ascending throughout.
    /// `nil` ⇒ the runaway guard tripped.
    private static func preRoll(before first: TimeInterval, _ shape: Shape) -> [Beat]? {
        guard first > 0 else { return [] }
        var backwards: [Beat] = []
        var index = -1
        var steps = 0
        while true {
            let time = first + Double(index) * shape.interval
            if time < -shape.epsilon { break }
            // An anchor placed past the end still grids the song before it, but never past it.
            if time <= shape.duration + shape.epsilon {
                backwards.append(shape.beat(at: time, index: index))
            }
            index -= 1
            steps += 1
            if steps > maxBeats { return nil }
        }
        return backwards.reversed()
    }

    /// Beats running forward from one anchor, stopping at `limit` — half an interval short of the
    /// next anchor, or the song's end for the last one. The bar count restarts here at 0, which is
    /// what makes an anchor a 1. `nil` ⇒ the runaway guard tripped.
    private static func segment(from anchor: TimeInterval, upTo limit: TimeInterval,
                                _ shape: Shape, budget: Int) -> [Beat]? {
        var beats: [Beat] = []
        var step = 0
        while true {
            let time = anchor + Double(step) * shape.interval
            if time > limit + shape.epsilon { break }
            if time >= -shape.epsilon { beats.append(shape.beat(at: time, index: step)) }
            step += 1
            if beats.count > budget { return nil }
        }
        return beats
    }

    /// Just the beat fractions (downbeats included) — the snap candidates a released
    /// gesture catches, the same shape `WaveformGesture.snap` already consumes.
    static func beatFractions(bpm: Double, duration: TimeInterval, downbeat: TimeInterval,
                              beatsPerBar: Int = 4) -> [Double] {
        beats(bpm: bpm, duration: duration, downbeat: downbeat, beatsPerBar: beatsPerBar)
            .map(\.fraction)
    }
}
