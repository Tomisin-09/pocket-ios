import Foundation

// MARK: - The grid from a beat map (ADR 0281)

extension BeatGrid {

    /// **The one way a song's grid is built.** Every reader of the grid calls this (the waveform,
    /// the song map, Count the notes), so a song with a beat map is gridded the same way
    /// everywhere and no reader can forget the map.
    ///
    /// A map wins when there is one (`BeatMap.isMap`); otherwise the song's one tempo is drawn as
    /// ADR 0022 and 0154 always have. No 1 placed, no grid, either way: the map knows where the
    /// beats are but not which of them starts a bar, and ADR 0022 doesn't guess the phase.
    static func beats(bpm: Double?, map: [TimeInterval], duration: TimeInterval,
                      anchors: [TimeInterval], beatsPerBar: Int = 4) -> [Beat] {
        if BeatMap.isMap(map) {
            return beats(map: map, duration: duration, anchors: anchors, beatsPerBar: beatsPerBar)
        }
        guard let bpm else { return [] }
        return beats(bpm: bpm, duration: duration, anchors: anchors, beatsPerBar: beatsPerBar)
    }

    /// The grid from a beat map: the map's own beats, carried to both ends of the song at the
    /// tempo at each end (`BeatMap.extended`), counted into bars from the 1.
    ///
    /// Each anchor marks **the beat nearest it** as a 1 (ADR 0281 D2). The primary is the song's 1;
    /// an ADR 0154 correction keeps the meaning it always had, *the bar count restarts here*, which
    /// on a map is for a short bar or a count that went wrong rather than for drift. Two anchors on
    /// the same beat are one. Before the first anchor the count runs backwards from it.
    ///
    /// Returns `[]` for a non-positive `duration`, no anchors, fewer than `BeatMap.minBeats` beats,
    /// or a grid past `maxBeats`.
    static func beats(map: [TimeInterval], duration: TimeInterval, anchors: [TimeInterval],
                      beatsPerBar: Int = 4) -> [Beat] {
        guard duration > 0,
              let times = BeatMap.extended(map, through: duration, limit: maxBeats) else { return [] }
        let ones = Set(anchors.compactMap { BeatMap.nearestIndex(to: $0, in: times) }).sorted()
        guard let first = ones.first else { return [] }
        let perBar = max(1, beatsPerBar)
        var nextOne = 0
        return times.enumerated().map { index, time in
            while nextOne + 1 < ones.count, ones[nextOne + 1] <= index { nextOne += 1 }
            let from = index < first ? first : ones[nextOne]
            let step = index - from
            return Beat(fraction: (time / duration).clamped(to: 0...1),
                        isDownbeat: ((step % perBar) + perBar) % perBar == 0)
        }
    }
}
