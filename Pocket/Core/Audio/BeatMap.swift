import Foundation

/// A song's **beat map** (ADR 0281): every beat with its own time, in song seconds, ascending.
///
/// One tempo and a 1 draw the grid as a straight line, and a band that played without a click
/// speeds up and settles, so the line drifts off the music (ADR 0154 cuts it into segments, but
/// each segment is still straight). A beat map stores the beats themselves, so the gap between two
/// beats *is* the tempo at that moment and nothing is assumed in between.
///
/// This file turns taps into a map and reads things back out of one. `BeatGrid` turns a map into
/// bars. Pure, with no SwiftUI or AVFoundation, so it is unit-tested like the grid (AGENTS.md).
enum BeatMap {

    /// A song's onset envelope (`WaveformExtractor.extractOnsetEnvelope`), as taps are snapped to it.
    struct Onsets: Sendable, Equatable {
        let values: [Double]
        let framesPerSecond: Double
    }

    /// Fewest beats that make a map. Three gaps is the least a median means anything over; fewer
    /// than that is a stray tap, not a song, and the grid falls back to one tempo.
    static let minBeats = 4

    /// How far either side of a tap the search for a hit reaches. A careful tap lands within about
    /// 50 ms of the beat; much wider and a tap on a beat catches a strum on the offbeat beside it.
    static let snapWindow: TimeInterval = 0.05

    /// How far either side of a tap the music is read, to judge whether a hit stands out from it.
    static let clarityContext: TimeInterval = 0.5

    /// How many times the surrounding level a hit must reach to be *clear*. The surrounding level
    /// is the median of the onset envelope over `clarityContext`; in a busy mix every frame has some
    /// flux, and a peak only a little above it is as likely the hi-hat as the beat.
    static let clarity = 2.0

    /// How many gaps at each end of a map set the tempo it is carried on at, past its first and
    /// last beat. Four is a bar of 4/4: enough to average a hand's jitter, close enough to the edge
    /// to be the tempo there rather than the song's.
    static let edgeGaps = 4

    /// A gap this many times the local beat is a missed beat or more, and gets filled.
    static let missedBeatRatio = 1.5

    /// Whether `times` is long enough to be a map.
    static func isMap(_ times: [TimeInterval]) -> Bool { times.count >= minBeats }

    /// The median gap between neighbouring beats, or `nil` with fewer than two beats.
    static func medianInterval(_ times: [TimeInterval]) -> TimeInterval? {
        let gaps = self.gaps(times).filter { $0 > 0 }
        guard !gaps.isEmpty else { return nil }
        return AudioMath.percentile(gaps, 0.5)
    }

    /// The map's headline tempo, from its median gap. This is what `Song.preciseBPM` holds while a
    /// song has a map, so every reader of one tempo (the readout, the metronome carry, count-ins)
    /// keeps working (ADR 0281 D3).
    static func medianBPM(_ times: [TimeInterval]) -> Double? {
        medianInterval(times).map { 60 / $0 }
    }

    /// The slowest and fastest tempo in the map, each read over a bar's worth of gaps (`window`)
    /// so one jittery tap doesn't widen the range. `nil` when there's less than one window.
    static func tempoRange(_ times: [TimeInterval], window: Int = edgeGaps) -> ClosedRange<Double>? {
        let gaps = self.gaps(times)
        guard window > 0, gaps.count >= window else { return nil }
        var slowest = Double.greatestFiniteMagnitude
        var fastest = 0.0
        for start in 0...(gaps.count - window) {
            let span = gaps[start..<(start + window)].reduce(0, +)
            guard span > 0 else { continue }
            let bpm = 60 * Double(window) / span
            slowest = min(slowest, bpm)
            fastest = max(fastest, bpm)
        }
        return fastest > 0 ? slowest...fastest : nil
    }

    // MARK: - From taps

    /// Taps through a song, made into a map.
    ///
    /// 1. **Sorted.** Taps read the playhead, so a loop that wrapped puts later taps earlier.
    /// 2. **Near-duplicates dropped.** Two taps closer than half a beat can't both be beats: it's a
    ///    fumble, or the same beat tapped on two passes of a loop. The earlier one is kept.
    /// 3. **Missed beats filled.** A gap of one and a half beats or more, against the gaps around
    ///    it, gets evenly spaced beats in it, so a missed tap doesn't shift every bar line after it.
    ///
    /// The beat used for steps 2 and 3 ignores gaps faster than `TempoMath.maxTapBPM`, which are
    /// the duplicates themselves and would otherwise drag the median toward zero.
    static func fromTaps(_ taps: [TimeInterval]) -> [TimeInterval] {
        let sorted = taps.filter { $0.isFinite && $0 >= 0 }.sorted()
        let fastest = 60 / TempoMath.maxTapBPM
        let plausible = gaps(sorted).filter { $0 >= fastest }
        guard !plausible.isEmpty else { return sorted.isEmpty ? [] : [sorted[0]] }
        let typical = AudioMath.percentile(plausible, 0.5)
        var kept: [TimeInterval] = []
        for tap in sorted {
            if let last = kept.last, tap - last < typical / 2 { continue }
            kept.append(tap)
        }
        return filled(kept)
    }

    /// `beats` with any missed beats put back. Each gap is judged against the median of the gaps
    /// around it (up to `edgeGaps` either side, itself excluded), so a song that slows for its
    /// bridge isn't mistaken for one that skipped a beat there.
    static func filled(_ beats: [TimeInterval]) -> [TimeInterval] {
        let gaps = self.gaps(beats)
        guard gaps.count >= 2 else { return beats }
        var result = [beats[0]]
        for (index, gap) in gaps.enumerated() {
            let neighbours = gaps[max(0, index - edgeGaps)..<index]
                + gaps[(index + 1)..<min(gaps.count, index + 1 + edgeGaps)]
            let local = AudioMath.percentile(Array(neighbours), 0.5)
            if local > 0, gap >= missedBeatRatio * local {
                let count = Int((gap / local).rounded())
                let step = gap / Double(count)
                for part in 1..<count { result.append(beats[index] + Double(part) * step) }
            }
            result.append(beats[index + 1])
        }
        return result
    }

    // MARK: - Snapping a tap onto a hit

    /// Each tap moved onto a clear hit within `snapWindow`, or left where it was.
    ///
    /// The ADR 0024 rule, narrowed: the 1 snaps to the loudest bar near where it's dropped, but a
    /// tap only moves when a hit **stands out** (`clarity`). On a quiet stretch with no clear hit a
    /// tap is a better guess than the strongest of several weak peaks.
    static func snapped(_ taps: [TimeInterval], to onsets: Onsets) -> [TimeInterval] {
        guard onsets.framesPerSecond > 0, onsets.values.count >= 3 else { return taps }
        return taps.map {
            clearHit(near: $0, onsets: onsets.values, framesPerSecond: onsets.framesPerSecond) ?? $0
        }
    }

    /// The time of the strongest clear peak in the onset envelope within `snapWindow` of `tap`, or
    /// `nil` when there isn't one. A peak is a frame higher than the one before and no lower than
    /// the one after, so a window that only catches the rising edge of a hit outside it finds none.
    static func clearHit(near tap: TimeInterval, onsets: [Double],
                         framesPerSecond: Double) -> TimeInterval? {
        let centre = Int((tap * framesPerSecond).rounded())
        let reach = Int((snapWindow * framesPerSecond).rounded())
        let lower = max(1, centre - reach)
        let upper = min(onsets.count - 2, centre + reach)
        guard lower <= upper else { return nil }

        var best: Int?
        for frame in lower...upper where onsets[frame] > onsets[frame - 1] && onsets[frame] >= onsets[frame + 1] {
            guard let current = best else { best = frame; continue }
            let louder = onsets[frame] > onsets[current]
            let nearer = onsets[frame] == onsets[current] && abs(frame - centre) < abs(current - centre)
            if louder || nearer { best = frame }
        }
        guard let best else { return nil }

        let context = Int((clarityContext * framesPerSecond).rounded())
        let around = Array(onsets[max(0, centre - context)...min(onsets.count - 1, centre + context)])
        let level = AudioMath.percentile(around, 0.5)
        guard onsets[best] > clarity * level else { return nil }
        return Double(best) / framesPerSecond
    }

    // MARK: - Reading a map as a whole song

    /// The map carried to both ends of the song: back to 0 at the tempo of its first `edgeGaps`
    /// gaps, and on to `duration` at the tempo of its last. A tap-through that started after the
    /// intro or stopped before the outro still grids the whole song, the way one tempo always has
    /// (ADR 0022's pre-roll). Beats outside `[0, duration]` are dropped, and so is any beat that
    /// doesn't come after the one before it.
    ///
    /// `nil` when `times` isn't a map, or the result would pass `limit` beats.
    static func extended(_ times: [TimeInterval], through duration: TimeInterval,
                         limit: Int) -> [TimeInterval]? {
        let epsilon = 1e-9
        let inside = times.filter { $0.isFinite && $0 >= -epsilon && $0 <= duration + epsilon }
            .reduce(into: [TimeInterval]()) { rising, time in
                if let last = rising.last, time <= last { return }
                rising.append(time)
            }
        guard isMap(inside), let first = inside.first, let last = inside.last,
              let head = medianInterval(Array(inside.prefix(edgeGaps + 1))),
              let tail = medianInterval(Array(inside.suffix(edgeGaps + 1))) else { return nil }

        var before: [TimeInterval] = []
        var time = first - head
        while time >= -epsilon {
            before.append(max(0, time))
            time -= head
            if before.count + inside.count > limit { return nil }
        }
        var after: [TimeInterval] = []
        time = last + tail
        while time <= duration + epsilon {
            after.append(min(duration, time))
            time += tail
            if before.count + inside.count + after.count > limit { return nil }
        }
        return before.reversed() + inside + after
    }

    /// The index of the beat in `times` (ascending) nearest `seconds`. The earlier wins a tie, so a
    /// 1 placed exactly between two beats lands on a consistent one. `nil` when `times` is empty.
    static func nearestIndex(to seconds: TimeInterval, in times: [TimeInterval]) -> Int? {
        guard !times.isEmpty else { return nil }
        var low = 0
        var high = times.count
        while low < high {
            let middle = (low + high) / 2
            if times[middle] < seconds { low = middle + 1 } else { high = middle }
        }
        guard low > 0 else { return 0 }
        guard low < times.count else { return times.count - 1 }
        return seconds - times[low - 1] <= times[low] - seconds ? low - 1 : low
    }

    private static func gaps(_ times: [TimeInterval]) -> [TimeInterval] {
        guard times.count >= 2 else { return [] }
        return (1..<times.count).map { times[$0] - times[$0 - 1] }
    }
}
