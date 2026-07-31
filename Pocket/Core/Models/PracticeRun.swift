import Foundation
import SwiftData

/// One **completed unit-run** in the practice log (ADR 0117) — the timestamped substrate every
/// time-windowed stat needs, and the only thing in the app that records *when* you practised.
///
/// **One row per unit-run, not per practice sit.** A sitting is not the thing a player improves at —
/// a *unit* is. A routine of six exercises practised at six different tempos writes six rows at its
/// six existing completion seams; sittings are recovered by **grouping rows on time**
/// (`PracticeLog.sittings`), so every session-level stat still works while the per-exercise tempo
/// trajectory stays derivable. Going the other way — per-sit rows migrated to per-unit later — would
/// cost testers their history.
///
/// **Append-only and cheap.** One insert when a run finishes its full course. No mutation, no
/// per-tick writes, nothing on the audio path.
///
/// **Deletion-safe.** The references to what was practised are **loose id copies**, never SwiftData
/// relationships: deleting an exercise must not delete the minutes you spent on it. This is the
/// deliberate opposite of the inventory counts in `PracticeStats`, which *can* go down.
///
/// **Never a grade (ADR 0070).** `tempoBPM` is a factual log of what was practised ("the A-minor run
/// at 120"), never a score. Nothing here measures how well it was played.
///
/// Field discipline follows `docs/swiftdata-gotchas.md`: every attribute is a **primitive**, `kind`
/// is a raw `String` with a computed accessor (a stored custom enum traps on device migration), and
/// every reference/tempo is `Optional` with no declaration default so lightweight migration is exempt
/// from the CoreData 134110 mandatory-attribute rule.
@Model
final class PracticeRun {
    /// Stable business id (ADR 0011/0012), matching every other model here — `persistentModelID` is
    /// unstable before insert, so it can't identify a row across a save.
    var uid: UUID

    /// When the run began — the spine of every time window. A run is attributed wholly to the day it
    /// *started* on, so one that crosses midnight doesn't split across two buckets.
    var startedAt: Date

    /// How long the run lasted. `Double` seconds rather than `endedAt`, because every consumer wants
    /// a duration to sum and none wants an end instant; `endedAt` is derived on `SessionRecord`.
    var durationSeconds: Double

    /// Backing storage for `kind` — a plain raw `String`, **not** a stored enum. A stored custom enum
    /// passes in-memory tests and traps on device migration (see the gotchas doc).
    var kindRaw: String

    /// The `uid` of the exercise or loop that was practised, or `nil` when the run isn't attributable
    /// to one unit. A **loose copy**, deliberately not a relationship: the row outlives the unit.
    var unitUID: UUID?

    /// The `uid` of the routine this run happened inside, or `nil` for a standalone run. Also loose —
    /// deleting a routine must not erase the practice done in it.
    var routineUID: UUID?

    /// The tempo the run was practised at, in **BPM** — exercises only. Purely factual (ADR 0070).
    var tempoBPM: Int?

    /// The tempo a *loop* run was practised at, as a **percent of original** (ADR 0082). Loops have no
    /// BPM of their own, so they get their own field rather than a unit discriminator: two fields that
    /// are never both set beat one field whose meaning has to be decoded before it can be compared.
    var tempoPercent: Int?

    /// The rhythm `tempoBPM` was measured in — notes per beat (ADR 0121) — or `nil` when the drill
    /// states none. A tempo without its rhythm is not comparable to another tempo, so a trajectory
    /// that ignored this would plot 90 in sixteenths against 90 in quarters as "no progress".
    var notesPerBeat: Int?

    init(uid: UUID = UUID(),
         startedAt: Date,
         durationSeconds: Double,
         kind: PracticeRunKind,
         unitUID: UUID? = nil,
         routineUID: UUID? = nil,
         tempoBPM: Int? = nil,
         tempoPercent: Int? = nil,
         notesPerBeat: Int? = nil) {
        self.uid = uid
        self.startedAt = startedAt
        self.durationSeconds = max(0, durationSeconds)
        self.kindRaw = kind.rawValue
        self.unitUID = unitUID
        self.routineUID = routineUID
        self.tempoBPM = tempoBPM
        self.tempoPercent = tempoPercent
        self.notesPerBeat = notesPerBeat
    }

    /// What was practised, decoded from the stored raw value. An unrecognised string — only reachable
    /// from a store written by a newer build — reads as `.other` rather than being mis-labelled as a
    /// kind it isn't; the minutes still count towards every total.
    var kind: PracticeRunKind {
        get { PracticeRunKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    /// The pure value this row hands to the aggregation layer. Every stat is computed over
    /// `[SessionRecord]`, never over `@Model`s, so the windowing math stays SwiftData-free and
    /// unit-testable (AGENTS.md) — the same shape `PracticeStats.summarize` already uses.
    var record: SessionRecord {
        SessionRecord(id: uid,
                      startedAt: startedAt,
                      durationSeconds: durationSeconds,
                      kind: kind,
                      unitUID: unitUID,
                      routineUID: routineUID,
                      tempoBPM: tempoBPM,
                      tempoPercent: tempoPercent,
                      notesPerBeat: notesPerBeat)
    }
}
