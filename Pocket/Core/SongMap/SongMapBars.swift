import Foundation

/// A time read as a place in the song's bars (ADR 0310 D3): so many bars from the first downbeat, and so
/// far into that bar. The whole part is the bar's index in `Grid.downbeats`, the rest how far into it, so
/// *4.25* is a quarter of the way into the fifth bar. Each bar is measured as it is, from its downbeat to
/// the next, so a beat map's bars (ADR 0281) read as they're played. Before the first downbeat and past the
/// last, bars run on at the grid's bar length.
///
/// This is what lets a copy keep a chord on beat 2 when the place it's copied to starts somewhere else in
/// its bar, and what a shift by a beat moves through.
enum SongMapBars {

    /// `seconds` as a place in the bars.
    static func place(of seconds: TimeInterval, in grid: SongMapInput.Grid) -> Double {
        let downbeats = grid.downbeats
        guard let first = downbeats.first, grid.barSeconds > 0 else { return 0 }
        guard seconds >= first else { return (seconds - first) / grid.barSeconds }
        // The last downbeat at or before `seconds`.
        var low = 0, high = downbeats.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if downbeats[middle] <= seconds { low = middle } else { high = middle - 1 }
        }
        return Double(low) + (seconds - downbeats[low]) / length(ofBar: low, in: grid)
    }

    /// The time at `place`: the other way round from `place(of:in:)`.
    static func seconds(at place: Double, in grid: SongMapInput.Grid) -> TimeInterval {
        let downbeats = grid.downbeats
        guard let first = downbeats.first else { return 0 }
        guard place >= 0 else { return first + place * grid.barSeconds }
        let index = min(Int(place.rounded(.down)), downbeats.count - 1)
        return downbeats[index] + (place - Double(index)) * length(ofBar: index, in: grid)
    }

    /// The bar `seconds` falls in, a hair early counting as the bar it's about to start: a loop's edges are
    /// stored as fractions of the song and read back a hair off (ADR 0232 D18).
    static func bar(of seconds: TimeInterval, in grid: SongMapInput.Grid) -> Double {
        place(of: seconds + SongMapLayout.tolerance, in: grid).rounded(.down)
    }

    /// How long bar `index` lasts: to the next downbeat, or the grid's bar length for the last.
    private static func length(ofBar index: Int, in grid: SongMapInput.Grid) -> TimeInterval {
        let downbeats = grid.downbeats
        guard index + 1 < downbeats.count else { return grid.barSeconds }
        let gap = downbeats[index + 1] - downbeats[index]
        return gap > 0 ? gap : grid.barSeconds
    }
}
