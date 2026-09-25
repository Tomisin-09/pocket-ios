import SwiftUI

/// `ExerciseRunView`'s **ramp derivations** — the backoff floor and the
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

    /// The Reach row's tempo — carrying **Reset to auto** only while it's pinned. Built here, typed,
    /// rather than as a ternary in the panel call, which the type-checker can't resolve inside `body`
    /// (see `songTapHandler`).
    var reachControl: PhaseTempoControl {
        var control = PhaseTempoControl(value: reach, onStep: { adjustReach(by: $0) },
                                        onType: { setReach($0) })
        if targetOverride != nil { control.onReset = { resetReach() } }
        return control
    }

    /// The Back off row's **Settle at**, with its reset while pinned — as `reachControl`.
    var settleAtControl: PhaseTempoControl {
        var control = PhaseTempoControl(value: backoff, onStep: { adjustBackoff(by: $0) },
                                        onType: { setBackoff($0) })
        if backoffOverride != nil { control.onReset = { resetBackoff() } }
        return control
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
    /// Nothing is written back: `persist()` saves the edit state (`shape`), never this fitted value, so
    /// running a generated session cannot rewrite the exercise's authored recipe (sub-decision 3).
    var routine: CommandRamp {
        let authored = CommandRamp(tempos: RampTempos(working: working, command: command,
                                                      reach: reach, backoff: backoff),
                                   shape: shape, backoffOverride: backoffOverride,
                                   intervalCount: StandaloneMetronomeEngine.automatorDefaultBars,
                                   unit: .bars)
        guard let planned = routineContext?.plannedMinutes else { return authored }
        return SessionEstimate.fitted(authored, toMinutes: planned, beatsPerBar: signature.beats)
    }
}
