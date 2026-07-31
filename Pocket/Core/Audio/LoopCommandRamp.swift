import Foundation

/// Maps a loop's command-anchored progression onto the shared `CommandRamp` staircase
/// (ADR 0046, Phase B). A loop trains the *same* warm-up → dwell → reach → back-off shape as a
/// metronome `Exercise`, but its tempo is a fraction of original (`×`), not absolute BPM — so the
/// `×` working / command / reach are expressed as **integer percent-of-original** (`0.85×` → `85`)
/// and fed to `CommandRamp` unchanged. `CommandRamp` is reused, not forked: the plateau math,
/// live cursor, and completion all work on percent, and `RoutineStairs` renders it as-is.
///
/// Intervals are counted in **loop repetitions** — one pass through the region is one step, which is
/// how a loop is actually practised ("play it through, then bump it up"). A loop has no metronome
/// bars, so the ramp reuses `CommandRamp`'s `.bars` interval mechanism with "bars" reinterpreted as
/// *loop passes*: the run driver feeds `PracticeAudioEngine.loopIteration` as the elapsed count.
/// That count is **rate-independent** (it counts musical repetitions, not frames), so a plateau
/// holds a fixed number of reps regardless of the tempo it plays at. Pure and UI-free so the percent
/// rounding (the kind of tempo math that breaks silently) is unit-tested per AGENTS.md.
enum LoopCommandRamp {

    /// Default loop passes each non-dwell plateau (warm-up / reach / back-off) holds — one rep per
    /// step, the natural "play it through, then step" unit (user-adjustable in the run setup).
    static let defaultRepsPerStep = 1
    /// Default intervals the command plateau dwells — the consolidation hold, in reps-per-step units
    /// (so the dwell runs `dwellIntervals × repsPerStep` passes).
    static let defaultDwellIntervals = 4

    /// `×`-of-original → integer percent (`0.85×` → `85`). Rounded to the nearest whole percent
    /// so the staircase reads in clean steps; `clamped` only against negatives (a loop speed is
    /// always positive in practice).
    static func percent(_ speed: Double) -> Int { max(0, Int((speed * 100).rounded())) }

    /// Build the staircase for a loop run from its `×` tempos + shaping params, in percent units.
    /// `warmupSteps` is the count of intermediate plateaus between working and command (the
    /// per-step BPM is derived, as in `ExerciseRunView`); `reachSteps`/`backoffSteps` shape the
    /// climb to and descent from the summit; `repsPerStep` is how many loop passes each plateau
    /// holds (the interval the run driver advances by `loopIteration`).
    static func make(working: Double, command: Double, target: Double,
                     warmupSteps: Int,
                     dwellIntervals: Int = defaultDwellIntervals,
                     reachSteps: Int = 0, backoffSteps: Int = 0,
                     includeBackoff: Bool = true, backoffOverride: Double? = nil,
                     repsPerStep: Int = defaultRepsPerStep) -> CommandRamp {
        let workingPct = percent(working)
        let commandPct = percent(command)
        let targetPct = percent(target)
        let stepBPM = CommandRamp.warmupStepBPM(working: workingPct, command: commandPct,
                                                intermediateSteps: max(0, warmupSteps))
        return CommandRamp(working: workingPct, command: commandPct, target: targetPct,
                           stepBPM: stepBPM, intervalCount: max(1, repsPerStep), unit: .bars,
                           dwellIntervals: max(1, dwellIntervals), includeBackoff: includeBackoff,
                           reachSteps: max(0, reachSteps), backoffSteps: max(0, backoffSteps),
                           backoffOverride: backoffOverride.map(percent))
    }

    /// Convenience: build the ramp directly from a `Loop`'s measured progression — `rampFloor` is the
    /// warm-up floor, `command` the owned tempo, `targetSpeed` the reach (a pinned override or the auto).
    ///
    /// Takes `rampFloor` rather than the raw `speed`: on an un-measured loop `command` *is* `speed`, so
    /// passing `speed` collapsed the staircase to dwell-plus-summit — no warm-up, no back off (ADR 0129
    /// sub-decision 1, extended to loops).
    static func make(loop: Loop, warmupSteps: Int,
                     dwellIntervals: Int = defaultDwellIntervals,
                     reachSteps: Int = 0, backoffSteps: Int = 0,
                     includeBackoff: Bool = true, backoffOverride: Double? = nil,
                     repsPerStep: Int = defaultRepsPerStep) -> CommandRamp {
        make(working: loop.rampFloor, command: loop.command, target: loop.targetSpeed,
             warmupSteps: warmupSteps, dwellIntervals: dwellIntervals,
             reachSteps: reachSteps, backoffSteps: backoffSteps,
             includeBackoff: includeBackoff, backoffOverride: backoffOverride, repsPerStep: repsPerStep)
    }
}
