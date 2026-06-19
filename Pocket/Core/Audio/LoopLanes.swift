import Foundation

/// Packs time intervals into the fewest horizontal lanes such that no two
/// intervals sharing a lane overlap — the classic greedy interval-graph
/// colouring (minimum lanes = maximum overlap depth).
///
/// The waveform uses it to stack saved-loop brackets: when loops overlap or
/// nest in time, the later one drops to the next lane down. Overlap is shown by
/// **vertical position**, never by colour — colour stays free to mean loop
/// *state* (active vs not). See ADR 0018.
///
/// Pure and UI-free so the packing — the logic that silently mis-stacks without
/// coverage — is exhaustively unit-tested (AGENTS.md). The drawing layer decides
/// how many lanes it can afford to show; this type always returns true lanes.
enum LoopLanes {

    /// One interval to place: a stable id and its `[start, end]` bounds as song
    /// fractions (`0...1`).
    struct Interval: Equatable {
        let id: UUID
        let start: Double
        let end: Double

        init(id: UUID, start: Double, end: Double) {
            self.id = id
            self.start = start
            self.end = end
        }
    }

    /// The result of packing: each interval's lane index (0 = bottom-most
    /// bracket row) plus the total number of lanes used.
    struct Packing: Equatable {
        var laneByID: [UUID: Int]
        var laneCount: Int

        /// The lane an interval landed in (0 if it wasn't in the input).
        func lane(for id: UUID) -> Int { laneByID[id] ?? 0 }
    }

    /// Assign every interval to the lowest-indexed lane whose previous interval
    /// has already ended, processing in start order (ties broken by end, then by
    /// id so the result is deterministic for a given set). Two intervals that
    /// merely touch at a point — one ends exactly where the next begins — may
    /// share a lane.
    static func pack(_ intervals: [Interval]) -> Packing {
        let ordered = intervals.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.end != $1.end { return $0.end < $1.end }
            return $0.id.uuidString < $1.id.uuidString
        }
        var laneEnds: [Double] = []          // end fraction of the last interval in each lane
        var laneByID: [UUID: Int] = [:]
        for interval in ordered {
            // Lowest lane that's free at this interval's start. `<=` lets loops
            // that touch at a single point share a lane.
            if let lane = laneEnds.firstIndex(where: { $0 <= interval.start }) {
                laneEnds[lane] = interval.end
                laneByID[interval.id] = lane
            } else {
                laneByID[interval.id] = laneEnds.count
                laneEnds.append(interval.end)
            }
        }
        return Packing(laneByID: laneByID, laneCount: laneEnds.count)
    }
}
