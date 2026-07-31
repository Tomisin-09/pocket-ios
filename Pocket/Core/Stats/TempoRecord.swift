import Foundation

/// **Faster than you'd played it before** (ADR 0117) — the moments the practice log shows a drill run
/// at a tempo it had never reached.
///
/// Read carefully against ADR 0070: this is *not* a score, a rank or a personal best table. It states
/// a fact about the log — "on the 12th you played this at 96, having previously topped out at 92" —
/// and it can only ever be arrived at by showing up. Nothing is compared to another player, no target
/// is implied, and a month with none of these is never described as a worse month.
///
/// **Rhythm-scoped (ADR 0121).** A tempo is only comparable with tempos measured in the same note
/// rate, so a drill has a separate ceiling per rhythm. Moving from eighths to sixteenths starts a new
/// ceiling rather than reading as a collapse — or, worse, dropping to quarters reading as a record.
///
/// **The first run at a rhythm is never one.** There is nothing to have beaten, and counting it would
/// mean every new drill announced a milestone on its first outing — noise that would drift the surface
/// towards a scoreboard.
enum TempoRecord {

    /// One run that exceeded everything logged before it for that drill at that rhythm.
    struct Entry: Equatable, Identifiable, Sendable {
        /// The `SessionRecord`'s own id, so a list of these is stable across re-renders.
        let id: UUID
        let unitUID: UUID
        let date: Date
        let bpm: Int
        /// The best tempo logged for this drill and rhythm *before* this run — always less than `bpm`.
        let previousBest: Int
        let noteRate: NoteRate?
    }

    /// A drill's ceiling is per-rhythm, so the running best is keyed on both. `perBeat` is the raw
    /// optional: an unstated rhythm is its own bucket, never folded into quarters.
    private struct Key: Hashable {
        let unitUID: UUID
        let perBeat: Int?
    }

    /// Every such run in the log, oldest first.
    ///
    /// Always computed over the **whole** log even when the caller only wants one month of it — a
    /// tempo is new relative to all of history, not relative to the window it's being displayed in.
    /// Filtering first would let last January's 120 be re-announced every month.
    static func entries(in records: [SessionRecord]) -> [Entry] {
        let candidates = records
            .filter { $0.kind == .exercise && $0.tempoBPM != nil }
            .sorted { $0.startedAt < $1.startedAt }

        var best: [Key: Int] = [:]
        var result: [Entry] = []
        for record in candidates {
            guard let bpm = record.tempoBPM, let unitUID = record.unitUID else { continue }
            let key = Key(unitUID: unitUID, perBeat: record.notesPerBeat)
            if let previous = best[key] {
                if bpm > previous {
                    result.append(Entry(id: record.id, unitUID: unitUID, date: record.startedAt,
                                        bpm: bpm, previousBest: previous, noteRate: record.noteRate))
                    best[key] = bpm
                }
            } else {
                best[key] = bpm     // the first run at this rhythm sets the bar; it doesn't clear one
            }
        }
        return result
    }

    /// The subset falling inside `interval` — computed from the full history first (see above), then
    /// windowed.
    static func entries(in records: [SessionRecord], within interval: DateInterval) -> [Entry] {
        entries(in: records).filter { interval.start <= $0.date && $0.date < interval.end }
    }
}
