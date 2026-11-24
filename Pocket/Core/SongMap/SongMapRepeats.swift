import Foundation

/// **How a loop's repeats step through the song** (ADR 0315): where each pass falls, how many there are,
/// and which taps repeat. The map's band and its *↻ ×N* (0232 D14), the Tab view's written-out passes
/// (0232 D18) and what Watch lights (0308 D2) all read their passes here, so the three agree.
///
/// - **With bars, a pass is the loop's length to the nearest whole bar**, at least one, exactly as a
///   copy's pass is (`SongMapCopy.period`, 0310 D3). A loop is drawn by hand and is almost never exactly
///   whole bars: *Sunday Morning*'s *Chords* is 10.837 s where four bars are 10.878 s, and stepping by
///   the length as drawn put each pass 41 ms early, a beat out by the Solo.
/// - **Each tap keeps its place in the bar**: read as so many bars into the song and so far into its bar
///   (`SongMapBars`), and sounded at the same place that many whole bars on. On a beat map (ADR 0281) a pass
///   follows the bars as played.
/// - **Without bars, a pass is the loop's length as drawn**, as it always was.
///
/// Pure and SwiftUI-free (AGENTS.md), so it's unit-tested with *Sunday Morning*'s own numbers.
enum SongMapRepeats {

    /// How far apart the passes are, in seconds: whole bars with a grid, the loop's length without.
    static func period(from start: TimeInterval, to end: TimeInterval, grid: SongMapInput.Grid?) -> TimeInterval {
        SongMapCopy.period(from: start, to: end, grid: grid)
    }

    /// How many times the loop plays from its start to `reach`, counting the one worked out, to the nearest
    /// whole pass. With bars it's counted in bars, so a beat map's longer and shorter bars count as bars.
    static func passes(from start: TimeInterval, to end: TimeInterval, reach: TimeInterval,
                       grid: SongMapInput.Grid?) -> Int {
        if let bars = bars(from: start, to: end, grid: grid), let grid {
            let span = SongMapBars.place(of: reach, in: grid) - SongMapBars.place(of: start, in: grid)
            return Int((span / Double(bars)).rounded())
        }
        let period = period(from: start, to: end, grid: grid)
        guard period > 0 else { return 1 }
        return Int(((reach - start) / period).rounded())
    }

    /// When a tap at `seconds` sounds on pass `pass`: as counted on pass 0, then a pass on each time.
    static func time(of seconds: TimeInterval, pass: Int, from start: TimeInterval, to end: TimeInterval,
                     grid: SongMapInput.Grid?) -> TimeInterval {
        guard pass > 0 else { return seconds }
        if let bars = bars(from: start, to: end, grid: grid), let grid {
            let place = SongMapBars.place(of: seconds, in: grid) + Double(pass * bars)
            return SongMapBars.seconds(at: place, in: grid)
        }
        return seconds + Double(pass) * period(from: start, to: end, grid: grid)
    }

    /// Whether a tap of the loop is one that repeats: one pass's worth from the loop's start. A loop drawn a
    /// hair over its whole bars has a tap or two in that hair, and they'd sound twice, on top of the next
    /// pass's first, if they repeated too. Without bars, every tap in the loop repeats.
    static func repeats(_ seconds: TimeInterval, from start: TimeInterval, to end: TimeInterval,
                        grid: SongMapInput.Grid?) -> Bool {
        guard let bars = bars(from: start, to: end, grid: grid), let grid else { return true }
        let into = SongMapBars.place(of: seconds, in: grid) - SongMapBars.place(of: start, in: grid)
        return into < Double(bars) - SongMapLayout.tolerance / grid.barSeconds
    }

    /// The passes to try for a tap so that every one up to `upTo` is covered: one more than the period says,
    /// because a beat map's bars can run longer than its bar length. A caller keeps only those in its stretch.
    static func passesToTry(from start: TimeInterval, to end: TimeInterval, upTo: TimeInterval,
                            grid: SongMapInput.Grid?) -> Int {
        let period = period(from: start, to: end, grid: grid)
        // A loop with no end (Watch's one-piece run) is played once, as counted.
        guard period > 0, period.isFinite, upTo.isFinite, upTo > start else { return 1 }
        return Int(((upTo - start) / period).rounded(.up)) + 1
    }

    /// Whole bars a pass is, when the song has bars to read places from.
    private static func bars(from start: TimeInterval, to end: TimeInterval, grid: SongMapInput.Grid?) -> Int? {
        guard let grid, grid.barSeconds > 0, !grid.downbeats.isEmpty else { return nil }
        return Int((period(from: start, to: end, grid: grid) / grid.barSeconds).rounded())
    }
}
