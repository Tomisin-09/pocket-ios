import Foundation

// MARK: - Which beat is the 1 (B4, ADR 0283)

extension BeatGrid {

    /// The 1 moved `beats` beats later along the grid it anchors (ADR 0283 D3). The player has heard
    /// the bar start on another beat than the one placed, so the 1 goes there. On a beat map that is
    /// the map's own beat, counted from the one nearest `placed` (the beat a map's anchor marks, ADR
    /// 0281 D2); on one tempo it is `beats` steps of `60 / bpm`. Moving by none is `placed` itself.
    /// `nil` when there is nothing to step along: no map and no tempo.
    static func one(_ placed: TimeInterval, movedBy beats: Int, bpm: Double?, map: [TimeInterval],
                    duration: TimeInterval) -> TimeInterval? {
        guard beats != 0 else { return placed }
        if BeatMap.isMap(map) {
            guard let times = BeatMap.extended(map, through: duration, limit: maxBeats),
                  let index = BeatMap.nearestIndex(to: placed, in: times) else { return nil }
            return times[min(max(index + beats, 0), times.count - 1)]
        }
        guard let bpm, bpm > 0 else { return nil }
        return placed + Double(beats) * 60 / bpm
    }
}

/// The 1 as the tempo sheet holds it before Done (ADR 0283 D3): where it was placed, and which beat
/// of the bar the player hears as the 1. Placing the 1 again starts the count again from it, so a
/// beat chosen against one placing is never applied to another.
struct DownbeatChoice: Equatable {
    /// Where the 1 was placed: marked, estimated, or the song's own. `nil` ⇒ none in the sheet.
    var placed: TimeInterval? { didSet { beat = 1 } }
    /// Which beat of the bar is the 1, counting the placed one as 1, as the buttons read.
    var beat = 1

    init(placed: TimeInterval?) { self.placed = placed }

    /// The beat chosen, or 1 once the bar is shorter than it (a 4 chosen, then 3 beats a bar).
    func beat(inBarOf beatsPerBar: Int) -> Int { (1...max(1, beatsPerBar)).contains(beat) ? beat : 1 }

    /// The 1 the sheet would commit: the placed one, moved to the chosen beat along the grid Done
    /// would leave. Where it can't move (no tempo yet), the placed one stands.
    func seconds(beatsPerBar: Int, bpm: Double?, map: [TimeInterval],
                 duration: TimeInterval) -> TimeInterval? {
        guard let placed else { return nil }
        return BeatGrid.one(placed, movedBy: beat(inBarOf: beatsPerBar) - 1, bpm: bpm, map: map,
                            duration: duration) ?? placed
    }
}
