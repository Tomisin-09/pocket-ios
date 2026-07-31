import Foundation

/// The per-exercise **tempo trajectory** (ADR 0117) — "I played this at 76 in June and I'm at 104
/// now", read straight off the practice log.
///
/// This is the *unit-level* read the Progress screen can't give: everything there windows at the
/// session level, whereas a trajectory is one drill's own history. It is the artefact that motivated
/// logging per unit-run in the first place — a per-sit log carries one tempo for a whole routine and
/// makes this underivable.
///
/// **Not a score (ADR 0070).** Every point is a fact about what was practised, in the order it was
/// practised. There is no target line, no expected slope, and a trajectory that goes down is not
/// reported as a regression — the player is the judge of what a slower day meant.
///
/// **Rhythm-aware (ADR 0121).** A BPM is only half a fact: 90 in sixteenths and 90 in quarters are
/// different tempos, so plotting them on one line would read a rhythm change as progress that never
/// happened. A trajectory therefore covers exactly **one** note rate — the one most recently
/// practised — and says how many runs at other rhythms it set aside rather than silently dropping them.
///
/// Pure and UI-free so the grouping and the first/latest picks are unit-tested (AGENTS.md).
enum TempoTrajectory {

    /// One logged tempo, in time order.
    struct Point: Equatable, Identifiable, Sendable {
        let id: UUID
        let date: Date
        let bpm: Int

        init(id: UUID = UUID(), date: Date, bpm: Int) {
            self.id = id
            self.date = date
            self.bpm = bpm
        }
    }

    /// A drill's tempo history at one rhythm, plus what was left out to keep it honest.
    struct Reading: Equatable, Sendable {
        /// Oldest first. Always at least two entries — a single point is not a trajectory, so
        /// `reading(for:in:)` returns `nil` rather than a one-point line that implies a direction.
        let points: [Point]
        /// The rhythm every point was measured in.
        let noteRate: NoteRate?
        /// Runs excluded because they were practised at a **different** rhythm. Surfaced so the
        /// readout can admit the history is partial instead of quietly showing a shorter one.
        let otherRhythmRuns: Int

        var first: Point { points[0] }
        var latest: Point { points[points.count - 1] }
        /// Change from the first logged tempo to the latest, in BPM. May be negative or zero; it is a
        /// difference, never a verdict.
        var change: Int { latest.bpm - first.bpm }
        var lowest: Int { points.lazy.map(\.bpm).min() ?? first.bpm }
        var highest: Int { points.lazy.map(\.bpm).max() ?? first.bpm }
    }

    /// Build the trajectory for one unit from the whole log, or `nil` when there isn't one to draw:
    /// no logged tempos, or only a single run at the most-recent rhythm (nothing to trace yet).
    ///
    /// Rows without a `tempoBPM` are ignored outright — a run that never stated a tempo can't sit on a
    /// tempo axis. Rows whose `notesPerBeat` is `nil` form their own group, which is correct: an
    /// exercise that states no rhythm (a chord-changing drill) has a genuinely unstated rate and
    /// compares only with its own past, never with a run that *did* declare one.
    static func reading(for unitUID: UUID, in records: [SessionRecord]) -> Reading? {
        let tempoRuns = records
            .filter { $0.unitUID == unitUID && $0.tempoBPM != nil && $0.kind == .exercise }
            .sorted { $0.startedAt < $1.startedAt }
        guard let mostRecent = tempoRuns.last else { return nil }

        // The rhythm currently being practised wins the line; earlier runs at a different rate are
        // counted and set aside. `notesPerBeat` is compared as the raw optional so "no stated rhythm"
        // is its own group rather than collapsing into quarters.
        let rate = mostRecent.notesPerBeat
        let matching = tempoRuns.filter { $0.notesPerBeat == rate }
        guard matching.count >= 2 else { return nil }

        return Reading(points: matching.map { Point(id: $0.id, date: $0.startedAt, bpm: $0.tempoBPM ?? 0) },
                       noteRate: rate.map { NoteRate(perBeat: $0) },
                       otherRhythmRuns: tempoRuns.count - matching.count)
    }

    /// How many times this unit has been run, at any tempo or rhythm — the count that goes beside the
    /// trajectory so a drill with one honest run still has something true to show. Includes runs with
    /// no logged tempo, because showing up is the thing being measured (ADR 0117).
    static func runCount(for unitUID: UUID, in records: [SessionRecord]) -> Int {
        records.lazy.filter { $0.unitUID == unitUID }.count
    }
}
