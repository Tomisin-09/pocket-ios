import Foundation
import SwiftData

/// The **one insert path** into the practice log (ADR 0117), mirroring `JournalWriter`: every seam
/// that finishes a unit-run comes through here, so the log can't grow a second way of being written
/// with slightly different rules.
///
/// Called from the run screens' natural-completion callbacks — the moment a ramp runs its full course
/// — which is one seam serving both a standalone run and a routine block, since a block *is* the same
/// run screen with a `RoutineRunContext`. Writing here rather than on the Done screen means a run
/// still logs when auto-advance skips that screen, when the block is ear-training (which has no Done
/// gate at all), and when the player backs out of it: the Done screen collects a self-rating and a
/// note, which are optional; the minutes are not.
///
/// A run that is **stopped by hand** logs nothing. That is deliberate — the log records completed
/// unit-runs, and an aborted run has no honest length or tempo to claim.
///
/// **The "one seam" above holds for the *ramped* screens only.** Ear training (ADR 0104) and
/// improvising (ADR 0135) are a shared core view inside several different hosts, not one screen with
/// an optional context — so the seam is per-host, and putting the call in the routine host alone left
/// the four standalone hosts logging nothing at all until 2026-08-18. Those two modes now clock from
/// `RampLessRunLog` on the shared core; the routine block still logs at its own Done/planned-length
/// seam, because there **skip and exit must keep logging nothing**.
@MainActor
enum PracticeLogWriter {

    /// Runs shorter than this are dropped as noise rather than logged. A real ramp is at least tens of
    /// seconds; anything under a second is a completion that fired without a run behind it, and a log
    /// full of zero-length rows would inflate the session count while adding no minutes.
    static let minimumSeconds: Double = 1

    /// Append one completed unit-run. Returns whether a row was written, so a caller can tell "logged"
    /// from "too short to be real" without inspecting the store.
    ///
    /// Saves immediately: the log is append-only and one insert cheap, and a practice session is
    /// exactly the kind of thing that ends with the app being backgrounded before the next autosave.
    @discardableResult
    static func log(kind: PracticeRunKind,
                    startedAt: Date,
                    endedAt: Date = .now,
                    unitUID: UUID?,
                    routineUID: UUID? = nil,
                    tempoBPM: Int? = nil,
                    tempoPercent: Int? = nil,
                    notesPerBeat: Int? = nil,
                    into context: ModelContext) -> Bool {
        let seconds = endedAt.timeIntervalSince(startedAt)
        guard seconds >= minimumSeconds else { return false }
        let run = PracticeRun(startedAt: startedAt,
                              durationSeconds: seconds,
                              kind: kind,
                              unitUID: unitUID,
                              routineUID: routineUID,
                              tempoBPM: tempoBPM,
                              tempoPercent: tempoPercent,
                              notesPerBeat: notesPerBeat)
        context.insert(run)
        try? context.save()
        return true
    }
}
