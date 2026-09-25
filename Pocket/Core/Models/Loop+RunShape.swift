import Foundation

/// A loop's run **shape** (ADR 0221 D8) — the loop mirror of `Exercise`'s: which phases play, how
/// many rungs each draws and how long each holds, read and written as one `RunShape` so the run
/// screen and the block preview can't store it differently.
///
/// Holds are in **passes**. A loop used to hold every plateau for a multiple of a player-set **reps
/// per step**; that multiplier is folded into the holds here, on read, and retired on the first save.
extension Loop {

    /// The shape as stored, every hold in passes.
    ///
    /// On a loop not yet saved through the phase rows the holds are still in intervals of
    /// `rampRepsPerStep` passes, so they are multiplied out: the warm-up, reach and back-off holds
    /// read as `repsPerStep` (their new fields default to one interval), and the dwell as
    /// `rampDwellIntervals × repsPerStep`. So the loop plays exactly what it played before, and shows
    /// it in passes. After `applyRunShape(_:)` the multiplier is `1` and this is the identity.
    var runShape: RunShape {
        let reps = max(1, rampRepsPerStep)
        return RunShape(includeWarmup: includeWarmup, includeReach: includeReach,
                        includeBackoff: includeBackoff,
                        warmupSteps: max(0, rampWarmupSteps), reachSteps: max(0, rampReachSteps),
                        backoffSteps: max(0, rampBackoffSteps),
                        warmupHold: max(1, rampWarmupHold) * reps,
                        dwell: max(1, rampDwellIntervals) * reps,
                        reachHold: max(1, rampReachHold) * reps,
                        backoffHold: max(1, rampBackoffHold) * reps)
    }

    /// Store a run's shape — the one write path for the run screen's Save and Start (ADR 0057) and the
    /// block preview's live edits. It writes the holds in passes and `rampRepsPerStep` as `1`, which
    /// is the fold D8 describes: from here on nothing multiplies them.
    func applyRunShape(_ shape: RunShape) {
        includeWarmup = shape.includeWarmup
        includeReach = shape.includeReach
        includeBackoff = shape.includeBackoff
        rampWarmupSteps = max(0, shape.warmupSteps)
        rampReachSteps = max(0, shape.reachSteps)
        rampBackoffSteps = max(0, shape.backoffSteps)
        rampWarmupHold = max(1, shape.warmupHold)
        rampDwellIntervals = max(1, shape.dwell)
        rampReachHold = max(1, shape.reachHold)
        rampBackoffHold = max(1, shape.backoffHold)
        rampRepsPerStep = 1
    }

    /// The speed a run of this loop **summits** at: the reach when Reach is on, and command itself
    /// when it's off, because a run that never went above command has nothing to raise to (ADR 0221
    /// D6). The completion offer's raise and the Loops library row read this.
    var summitSpeed: Double { includeReach ? targetSpeed : command }

    /// The tempos the run spans, in integer percent — `rampFloor` rather than the raw `speed`, so the
    /// staircase the model describes is the one a run performs (ADR 0129 sub-decision 1).
    var rampTempos: RampTempos {
        RampTempos(working: LoopCommandRamp.percent(rampFloor),
                   command: LoopCommandRamp.percent(command),
                   reach: LoopCommandRamp.percent(targetSpeed), backoff: backoffPercent)
    }

    /// The command-anchored **training ramp** this loop prescribes (ADR 0046 Phase B) — warm up →
    /// dwell at command → summit at the reach → back off, in percent units and passes, from the saved
    /// shape, so the routine player (ADR 0066) runs a stored recipe with no setup UI. Pure/UI-free.
    var ramp: CommandRamp {
        LoopCommandRamp.make(tempos: rampTempos, shape: runShape,
                             backoffOverride: backoffSpeedOverride.map(LoopCommandRamp.percent))
    }
}
