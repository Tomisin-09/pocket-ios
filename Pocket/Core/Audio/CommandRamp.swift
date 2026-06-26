import Foundation

/// What the standalone metronome's `tick()` needs from whichever ramp is driving the tempo
/// (ADR 0045): the BPM at a given elapsed, and whether the ramp has finished so the click can
/// stop. Lets the engine drive either the free-play linear `MetronomeAutomator` or the
/// exercise `CommandRamp` through one call site.
protocol TempoRamp {
    func bpm(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Int
    func isFinished(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Bool
}

/// A **command-anchored** practice ramp (ADR 0045): the staircase an exercise climbs once it
/// has a command tempo, in place of the free-play linear ramp. Four phases —
///
/// 1. **warm-up** — step from the working floor up to command,
/// 2. **dwell** — hold at command for the bulk of the reps (where consolidation happens),
/// 3. **summit** — a brief hold at the target reach, and
/// 4. **backoff** — a tail below command, to end the session on clean control not the edge.
///
/// Keyed on elapsed bars or seconds like `MetronomeAutomator`, and exposing the same
/// `bpm(…)` / `completionInterval` / `isFinished(…)` surface so the engine drives it the same
/// way — but the plateaus are **uneven** (the command dwell holds longer), so it can't be the
/// linear stepper. Pure and UI-free so the plateau math (the logic that breaks silently) is
/// exhaustively unit-tested per AGENTS.md.
struct CommandRamp: Equatable, TempoRamp {
    /// Warm-up floor — where the ramp begins.
    var working: Int
    /// The owned tempo the ramp dwells at.
    var command: Int
    /// The reach summited briefly above command.
    var target: Int
    /// BPM added per warm-up step (positive magnitude; ≤ 0 ⇒ no warm-up, start at command).
    var stepBPM: Int
    /// Elapsed `unit`s per held interval (every warm-up/summit/backoff plateau holds one).
    var intervalCount: Int
    /// Whether the interval is counted in bars or seconds.
    var unit: MetronomeIntervalUnit
    /// How many intervals the command plateau holds — the dwell. Treated as ≥ 1.
    var dwellIntervals: Int
    /// Whether to append the backoff tail below command.
    var includeBackoff: Bool

    /// One held tempo and how many `intervalCount`-units it holds for.
    struct Plateau: Equatable {
        var bpm: Int
        var intervals: Int
    }

    /// The warm-up `stepBPM` that places `intermediateSteps` plateaus **strictly between**
    /// the `working` floor and `command` (ADR 0045, Training Mode). `0` ⇒ jump straight from
    /// working to command (one warm-up plateau, no intermediate stops). Always ≥ 1 BPM so the
    /// ramp advances, and `1` when there's no climb (`command ≤ working`).
    static func warmupStepBPM(working: Int, command: Int, intermediateSteps: Int) -> Int {
        let span = command - working
        guard span > 0 else { return 1 }
        let divisions = max(1, intermediateSteps + 1)
        return max(1, Int((Double(span) / Double(divisions)).rounded()))
    }

    /// The inverse of `warmupStepBPM`: how many intermediate plateaus a stored `stepBPM`
    /// puts between `working` and `command` — to seed the Training Mode stepper from the
    /// saved granularity. `0` when the step jumps straight to command or there's no climb.
    static func intermediateSteps(working: Int, command: Int, stepBPM: Int) -> Int {
        let span = command - working
        guard span > 0, stepBPM > 0 else { return 0 }
        return max(0, Int((Double(span) / Double(stepBPM)).rounded()) - 1)
    }

    /// The ordered plateaus, warm-up floor through backoff tail. Warm-up, summit and backoff
    /// each hold one interval; the command plateau holds `dwellIntervals`. The summit is
    /// dropped when `target ≤ command`, and the backoff when it wouldn't sit below command.
    var plateaus: [Plateau] {
        var result: [Plateau] = []
        if stepBPM > 0, command > working {
            var bpm = working
            while bpm < command {
                result.append(Plateau(bpm: bpm, intervals: 1))
                bpm += stepBPM
            }
        }
        result.append(Plateau(bpm: command, intervals: max(1, dwellIntervals)))
        if target > command {
            result.append(Plateau(bpm: target, intervals: 1))
        }
        if includeBackoff {
            let backoff = TempoStretch.backoffBPM(command: command, target: target, floor: working)
            if backoff < command {
                result.append(Plateau(bpm: backoff, intervals: 1))
            }
        }
        return result
    }

    /// The tempo after `elapsedBars` bars / `elapsedSeconds` seconds: the plateau the elapsed
    /// interval count lands in, held at the final plateau once the ramp completes.
    func bpm(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Int {
        let steps = plateaus
        guard intervalCount > 0, let last = steps.last else { return working }
        let elapsed: Double = unit == .bars ? Double(max(0, elapsedBars)) : max(0, elapsedSeconds)
        let intervalsElapsed = Int(elapsed / Double(intervalCount))
        var cumulative = 0
        for plateau in steps {
            cumulative += plateau.intervals
            if intervalsElapsed < cumulative { return plateau.bpm }
        }
        return last.bpm
    }

    /// Total intervals across all plateaus — the ramp's length in interval units.
    var totalIntervals: Int { plateaus.reduce(0) { $0 + $1.intervals } }

    /// The elapsed `unit`-count at which the ramp has held its final (backoff/summit) plateau
    /// for its full duration, so the engine can stop. `nil` when there are no plateaus.
    var completionInterval: Int? {
        guard intervalCount > 0, !plateaus.isEmpty else { return nil }
        return totalIntervals * intervalCount
    }

    /// Whether the ramp has finished — the final plateau's hold has elapsed.
    func isFinished(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Bool {
        guard let completionInterval else { return false }
        let elapsed: Double = unit == .bars ? Double(max(0, elapsedBars)) : max(0, elapsedSeconds)
        return elapsed >= Double(completionInterval)
    }
}
