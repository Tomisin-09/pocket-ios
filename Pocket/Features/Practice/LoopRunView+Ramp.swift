import SwiftUI

/// `LoopRunView`'s **ramp derivations** — the reach and back off, the phase rows' tempo controls, and
/// the `CommandRamp` the staircase draws and the run plays. The twin of `ExerciseRunView+Ramp.swift`,
/// split out for the same reason: one concern, turning the screen's live edit state into the staircase.
///
/// These read the view's `@State` rather than the `Loop`, deliberately — edits are held locally until
/// Start or Save (ADR 0057), so the preview must reflect what is on screen, not what is stored.
extension LoopRunView {

    /// The **auto** reach (% of original) derived from the (local) command — proportional + clamped
    /// via the `×`-unit `TempoStretch`, mapped back to percent. The fallback for reset-to-auto.
    var autoReach: Int {
        LoopCommandRamp.percent(TempoStretch.targetSpeed(forCommand: Double(command) / 100))
    }

    /// The **effective** reach (% of original): a pinned override when set, else the auto reach
    /// (ADR 0075). Every surface here reads this — the staircase summit, the rows, the offer.
    var reach: Int { targetOverride ?? autoReach }

    /// The **auto** backoff floor (% of original) for the current tempos — the reset-to-auto fallback
    /// (user-testing note 6). The same percent-space derivation `CommandRamp` uses when unpinned.
    var autoBackoff: Int { TempoStretch.backoffBPM(command: command, target: reach, floor: working) }

    /// The **effective** backoff floor (% of original): a pinned override when set, else the auto value.
    var backoff: Int { backoffOverride ?? autoBackoff }

    /// The Reach row's tempo — carrying **Reset to auto** only while it's pinned. Built here, typed,
    /// rather than as a ternary in the panel call, which the type-checker can't resolve inside `body`.
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
    /// (percent units, one pass per interval) handed to the run on Start.
    ///
    /// Inside a **generated** session the block's allotted minutes win: the ramp is fitted to the slot
    /// by stretching the dwell — for a loop, more passes at command — bounded against the authored
    /// dwell (ADR 0129 as amended). Nothing is written back; `persist()` saves the edit state, never
    /// the fitted value.
    var routine: CommandRamp {
        let authored = LoopCommandRamp.make(
            tempos: RampTempos(working: working, command: command, reach: reach, backoff: backoff),
            shape: shape, backoffOverride: backoffOverride)
        guard let planned = routineContext?.plannedMinutes else { return authored }
        return LoopEstimate.fitted(authored, toMinutes: planned,
                                   regionSeconds: loop.regionSeconds)
    }
}
