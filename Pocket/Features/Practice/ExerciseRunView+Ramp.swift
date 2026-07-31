import SwiftUI

/// `ExerciseRunView`'s **ramp derivations** — the backoff floor, the warm-up step size, and the
/// `CommandRamp` the staircase preview draws and `engine.run(ramp:)` plays. Split out of
/// `ExerciseRunView` to keep that file under the 400-line cap, and grouped because they are one
/// concern: turning the screen's live edit state into the staircase.
///
/// These read the view's `@State` rather than the `Exercise`, deliberately — edits are held locally
/// until Start or Save (ADR 0057), so the preview must reflect what is on screen, not what is stored.
extension ExerciseRunView {

    /// The **auto** backoff floor for the current tempos — the reset-to-auto fallback (note 6).
    var autoBackoff: Int { TempoStretch.backoffBPM(command: command, target: reach, floor: working) }

    /// The **effective** backoff floor: a pinned override when set, else the auto value (note 6).
    var backoff: Int { backoffOverride ?? autoBackoff }

    /// The warm-up step size the chosen number of intermediate stops implies.
    var stepBPM: Int {
        CommandRamp.warmupStepBPM(working: working, command: command, intermediateSteps: steps)
    }

    /// The routine the current edits describe — the staircase preview and the exact `CommandRamp`
    /// handed to `engine.run(ramp:)` on Start.
    ///
    /// Inside a **generated** session the block's allotted minutes win: the ramp is fitted to the slot
    /// (ADR 0129) by stretching the command dwell, so a block that says five minutes takes five. The
    /// fit lands here rather than in the player so the staircase the player *sees* is the staircase
    /// they will *hear* — one expression, both consumers. Standalone runs and hand-authored routines
    /// carry no planned minutes and are completely unaffected.
    ///
    /// Nothing is written back: `persist()` saves the edit state (`dwell`), never this fitted value, so
    /// running a generated session cannot rewrite the exercise's authored recipe (sub-decision 3).
    var routine: CommandRamp {
        let authored = CommandRamp(working: working, command: command, target: reach,
                                   stepBPM: stepBPM,
                                   intervalCount: StandaloneMetronomeEngine.automatorDefaultBars,
                                   unit: .bars, dwellIntervals: max(1, dwell),
                                   includeBackoff: includeBackoff, reachSteps: reachSteps,
                                   backoffSteps: backoffSteps, backoffOverride: backoffOverride)
        guard let planned = routineContext?.plannedMinutes else { return authored }
        return SessionEstimate.fitted(authored, toMinutes: planned, beatsPerBar: signature.beats)
    }
}
