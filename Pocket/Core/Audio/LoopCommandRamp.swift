import Foundation

/// Maps a loop's command-anchored progression onto the shared `CommandRamp` staircase
/// (ADR 0046, Phase B). A loop trains the *same* warm-up → dwell → reach → back-off shape as a
/// metronome `Exercise`, but its tempo is a fraction of original (`×`), not absolute BPM — so the
/// `×` working / command / reach are expressed as **integer percent-of-original** (`0.85×` → `85`)
/// and fed to `CommandRamp` unchanged. `CommandRamp` is reused, not forked: the plateau math,
/// live cursor, and completion all work on percent, and `RoutineStairs` renders it as-is.
///
/// Intervals are counted in **seconds** (a loop has no metronome "bars"); the run driver steps the
/// ramp by elapsed playback seconds and applies `bpm(elapsedSeconds:) / 100` as the time-stretch
/// rate. Pure and UI-free so the percent rounding (the kind of tempo math that breaks silently) is
/// unit-tested per AGENTS.md.
enum LoopCommandRamp {

    /// Default seconds each non-dwell plateau (warm-up / reach / back-off) holds in a loop run.
    static let defaultSecondsPerPlateau = 12
    /// Default intervals the command plateau dwells — the consolidation hold (≈ `dwell × seconds`).
    static let defaultDwellIntervals = 4

    /// `×`-of-original → integer percent (`0.85×` → `85`). Rounded to the nearest whole percent
    /// so the staircase reads in clean steps; `clamped` only against negatives (a loop speed is
    /// always positive in practice).
    static func percent(_ speed: Double) -> Int { max(0, Int((speed * 100).rounded())) }

    /// Build the staircase for a loop run from its `×` tempos + shaping params, in percent units.
    /// `warmupSteps` is the count of intermediate plateaus between working and command (the
    /// per-step BPM is derived, as in `ExerciseRunView`); `reachSteps`/`backoffSteps` shape the
    /// climb to and descent from the summit.
    static func make(working: Double, command: Double, target: Double,
                     warmupSteps: Int,
                     dwellIntervals: Int = defaultDwellIntervals,
                     reachSteps: Int = 0, backoffSteps: Int = 0,
                     includeBackoff: Bool = true,
                     secondsPerPlateau: Int = defaultSecondsPerPlateau) -> CommandRamp {
        let workingPct = percent(working)
        let commandPct = percent(command)
        let targetPct = percent(target)
        let stepBPM = CommandRamp.warmupStepBPM(working: workingPct, command: commandPct,
                                                intermediateSteps: max(0, warmupSteps))
        return CommandRamp(working: workingPct, command: commandPct, target: targetPct,
                           stepBPM: stepBPM, intervalCount: max(1, secondsPerPlateau), unit: .seconds,
                           dwellIntervals: max(1, dwellIntervals), includeBackoff: includeBackoff,
                           reachSteps: max(0, reachSteps), backoffSteps: max(0, backoffSteps))
    }

    /// Convenience: build the ramp directly from a `Loop`'s measured progression — `speed` is the
    /// warm-up floor, `command` the owned tempo, `derivedTargetSpeed` the reach.
    static func make(loop: Loop, warmupSteps: Int,
                     dwellIntervals: Int = defaultDwellIntervals,
                     reachSteps: Int = 0, backoffSteps: Int = 0,
                     includeBackoff: Bool = true,
                     secondsPerPlateau: Int = defaultSecondsPerPlateau) -> CommandRamp {
        make(working: loop.speed, command: loop.command, target: loop.derivedTargetSpeed,
             warmupSteps: warmupSteps, dwellIntervals: dwellIntervals,
             reachSteps: reachSteps, backoffSteps: backoffSteps,
             includeBackoff: includeBackoff, secondsPerPlateau: secondsPerPlateau)
    }
}
