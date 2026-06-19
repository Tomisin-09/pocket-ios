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
    /// `beatsPerBar` is treated as at least 1.
    static func beats(bpm: Int, duration: TimeInterval, downbeat: TimeInterval,
                      beatsPerBar: Int = 4) -> [Beat] {
        guard bpm > 0, duration > 0 else { return [] }
        let interval = 60.0 / Double(bpm)
        guard interval > 0 else { return [] }
        let perBar = max(1, beatsPerBar)

        // Integer beat indices k (relative to the anchor) whose time lands in
        // [0, duration]. A tiny epsilon absorbs float error so a beat sitting exactly
        // on an edge isn't dropped by `floor`/`ceil`.
        let epsilon = interval * 1e-9
        let kMin = Int(((-downbeat - epsilon) / interval).rounded(.up))
        let kMax = Int(((duration - downbeat + epsilon) / interval).rounded(.down))
        guard kMin <= kMax, kMax - kMin + 1 <= maxBeats else { return [] }

        var result: [Beat] = []
        result.reserveCapacity(kMax - kMin + 1)
        for beatIndex in kMin...kMax {
            let time = downbeat + Double(beatIndex) * interval
            let fraction = (time / duration).clamped(to: 0...1)
            // True modulo so negative indices (beats before the anchor) group correctly.
            let isDownbeat = ((beatIndex % perBar) + perBar) % perBar == 0
            result.append(Beat(fraction: fraction, isDownbeat: isDownbeat))
        }
        return result
    }

    /// Just the beat fractions (downbeats included) — the snap candidates a released
    /// gesture catches, the same shape `WaveformGesture.snap` already consumes.
    static func beatFractions(bpm: Int, duration: TimeInterval, downbeat: TimeInterval,
                              beatsPerBar: Int = 4) -> [Double] {
        beats(bpm: bpm, duration: duration, downbeat: downbeat, beatsPerBar: beatsPerBar)
            .map(\.fraction)
    }
}
