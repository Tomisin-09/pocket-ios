import Foundation
import SwiftData

/// Gives a mode to every **loop take recorded before ADR 0265**, read off the practice log. It runs
/// once at launch, beside the other backfills.
///
/// Until 0265 a take stored no mode, so its Journal caption opened ADR 0142's precedence, and a take
/// recorded in Train your ear on a loop with a tempo opened the ramp. A take's `createdAt` is its
/// **stop** time (`RecordingController.stopRecording` builds the row), so it falls inside the run it
/// was recorded in, and that run's kind names the mode.
///
/// **Runs once, not every launch.** A take with no matching run stays `nil` for good. Checking it
/// again on every launch would fetch the whole practice log every time and find nothing new. Takes
/// recorded from now on carry their mode from capture.
///
/// **What it can't recover** (ADR 0265): a routine block that was skipped or exited (nothing was
/// logged), a run shorter than `PracticeLogWriter.minimumSeconds`, and a take restored later from an
/// archive written before 0265. Each keeps the precedence, which is how it behaved before.
enum TakeModeBackfill {

    /// `UserDefaults` key guarding the one-time run.
    static let backfillKey = "takeModeBackfill.v1"

    /// How far outside a run's span a take may still fall and count as recorded in it. The take is
    /// finalised and the run logged by two `.onDisappear`s, which fire in either order, so the stop
    /// time can land a moment after the logged end or before the logged start.
    static let slack: TimeInterval = 5

    /// Give each mode-less loop take the mode of the run it was recorded in. Fetches **all** takes and
    /// filters in memory, never an optional `#Predicate` (the SwiftData optional-predicate freeze).
    /// Safe to call on every launch; it does nothing after the first run.
    ///
    /// A failed fetch or save leaves the key unset, so the next launch tries again rather than
    /// marking as done a pass that never happened.
    static func runIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: backfillKey) else { return }
        guard let all = try? context.fetch(FetchDescriptor<Recording>()) else { return }
        let takes = all.filter { $0.loop != nil && $0.loopRunModeRaw == nil }
        guard !takes.isEmpty else {
            // Nothing to fill: don't fetch the practice log for nothing.
            defaults.set(true, forKey: backfillKey)
            return
        }
        guard let runs = try? context.fetch(FetchDescriptor<PracticeRun>()) else { return }
        let byLoop = Dictionary(grouping: runs.map(\.record), by: \.unitUID)
        var wrote = false
        for take in takes {
            guard let loop = take.loop,
                  let found = mode(forTakeAt: take.createdAt, loopUID: loop.uid,
                                   runs: byLoop[loop.uid] ?? []) else { continue }
            take.loopRunModeRaw = found.rawValue
            wrote = true
        }
        if wrote {
            do { try context.save() } catch { return }
        }
        defaults.set(true, forKey: backfillKey)
    }

    /// The mode a take recorded at `takenAt` on the loop `loopUID` was recorded in, or `nil` when the
    /// log can't say. Pure, over plain values, so it is tested without a store.
    ///
    /// It looks at the runs on **this loop** whose kind is a loop mode and whose span, widened by
    /// `slack` at both ends, contains the take. Exactly one mode among them is the answer. None means
    /// no record of the run; more than one means two runs on the loop sit within seconds of the take,
    /// and the log can't tell which one it belongs to. Both answer `nil`, and the take keeps the
    /// precedence rather than taking a guess.
    static func mode(forTakeAt takenAt: Date, loopUID: UUID, runs: [SessionRecord]) -> LoopRunMode? {
        let modes = Set(runs.compactMap { run -> LoopRunMode? in
            guard run.unitUID == loopUID, let mode = run.kind.loopRunMode else { return nil }
            let start = run.startedAt.addingTimeInterval(-slack)
            let end = run.startedAt.addingTimeInterval(run.durationSeconds + slack)
            return (start...end).contains(takenAt) ? mode : nil
        })
        return modes.count == 1 ? modes.first : nil
    }
}
