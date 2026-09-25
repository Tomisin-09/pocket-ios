import Foundation

/// What the standalone metronome's `tick()` needs from whichever ramp is driving the tempo
/// (ADR 0045): the BPM at a given elapsed, and whether the ramp has finished so the click can
/// stop. Lets the engine drive either the free-play linear `MetronomeAutomator` or the
/// exercise `CommandRamp` through one call site.
protocol TempoRamp {
    func bpm(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Int
    func isFinished(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Bool
    /// The next tempo boundary and its distance (ADR 0131), or `nil` when nothing is coming — a flat
    /// or disabled ramp, or one that has already finished.
    ///
    /// Takes **fractional** bars, unlike the rest of this protocol. The warning lives inside the final
    /// interval of a plateau, so whole-bar resolution cannot express it: on a one-interval plateau the
    /// half-plateau clamp asks for half a bar's notice, which integer bars would round away to never.
    func pendingChange(elapsedBars: Double, elapsedSeconds: TimeInterval) -> PendingTempoChange?
}

/// A **command-anchored** practice ramp (ADR 0045): the staircase an exercise climbs once it
/// has a command tempo, in place of the free-play linear ramp. Four phases —
///
/// 1. **warm-up** — step from the working floor up to command,
/// 2. **dwell** — hold at command for the bulk of the reps (where consolidation happens),
/// 3. **summit** — a brief hold at the target reach, and
/// 4. **backoff** — a tail below command, to end the session on clean control not the edge.
///
/// Only the dwell is mandatory (ADR 0221 D2): the warm-up, the reach and the backoff each have a
/// switch, and a run with all three off is one plateau at command. A switch drops its phase's
/// plateaus and nothing else — the floor, a pinned reach and a pinned backoff are still read, so
/// switching a phase back on brings back the tempo it had.
///
/// Keyed on elapsed bars or seconds like `MetronomeAutomator`, and exposing the same
/// `bpm(…)` / `completionInterval` / `isFinished(…)` surface so the engine drives it the same
/// way — but the plateaus are **uneven** (each phase holds for its own length), so it can't be the
/// linear stepper. Pure and UI-free so the plateau math (the logic that breaks silently) is
/// exhaustively unit-tested per AGENTS.md.
struct CommandRamp: Equatable, TempoRamp {
    /// Warm-up floor — where the ramp begins.
    var working: Int
    /// The owned tempo the ramp dwells at.
    var command: Int
    /// The reach summited briefly above command.
    var target: Int
    /// Intermediate plateaus on the climb from the floor up to command (ADR 0221 D4), so the warm-up
    /// draws `warmupSteps + 1` rungs: the floor, then these. `0` ⇒ the floor alone, then command.
    /// Placed **by count**, like `reachSteps` — it replaced a `stepBPM` stride whose rounding added
    /// and dropped rungs (51 → 61 set to 6 intermediate stops played ten).
    var warmupSteps: Int
    /// Elapsed `unit`s per held interval — the quantum every hold below is counted in.
    var intervalCount: Int
    /// Whether the interval is counted in bars or seconds.
    var unit: MetronomeIntervalUnit
    /// How many intervals the command plateau holds — the dwell. Treated as ≥ 1.
    var dwellIntervals: Int
    /// Whether to append the backoff tail below command.
    var includeBackoff: Bool
    /// Intermediate plateaus on the climb from command up to the reach (summit). `0` ⇒ a single
    /// jump straight to the reach (the original behaviour). Defaulted so existing call sites are
    /// unaffected.
    var reachSteps: Int = 0
    /// Intermediate plateaus on the descent from the summit down to the backoff floor. `0` ⇒ a
    /// single drop to the backoff tail (the original behaviour). Defaulted, as `reachSteps`.
    var backoffSteps: Int = 0
    /// A manually pinned **backoff floor** (BPM) — the tempo the tail settles to (user-testing note
    /// 6). `nil` derives it from `TempoStretch.backoffBPM` (the original behaviour). Honoured only
    /// while `includeBackoff` and when it sits below `command`. Defaulted so existing call sites are
    /// unaffected (the synthesized memberwise init still defaults an omitted optional to `nil`).
    var backoffOverride: Int?
    /// Whether to climb from the floor at all (ADR 0221 D2). Off ⇒ the run opens at command.
    var includeWarmup = true
    /// Whether to summit above command (ADR 0221 D2). Off ⇒ the run never goes above command, and
    /// the backoff descends from command itself.
    var includeReach = true
    /// Intervals **each** warm-up rung holds (ADR 0221 D3). Treated as ≥ 1.
    var warmupHold = 1
    /// Intervals each reach rung holds, the summit included. Treated as ≥ 1.
    var reachHold = 1
    /// Intervals each backoff rung holds, the floor included. Treated as ≥ 1.
    var backoffHold = 1

    /// One held tempo and how many `intervalCount`-units it holds for.
    struct Plateau: Equatable {
        var bpm: Int
        var intervals: Int
    }

    /// The most rungs a phase can draw (ADR 0221 D4): steps run 1…7, as the old 0…6 intermediate
    /// stops did.
    static let maxRungs = 7

    /// How many rungs a phase spanning `from` → `to` **draws** when asked for `steps` intermediate
    /// stops: `steps + 1`, but never more than the gap, because seven rungs across a 3-BPM gap would
    /// repeat tempos. Always ≥ 1. The one rule every Steps control and every plateau list reads, so
    /// the number shown is the number drawn (ADR 0221 D4).
    static func rungs(steps: Int, from: Int, to: Int) -> Int {
        min(max(0, steps) + 1, maxRungs, max(1, abs(to - from)))
    }

    /// The warm-up `stepBPM` that places `intermediateSteps` plateaus between `working` and
    /// `command` — the **average** spacing. Since ADR 0221 D4 nothing builds a ramp from it; it
    /// survives only as the loop panel's "+N % per step" caption, until step 2 of that ADR moves
    /// loops to the phase rows. Always ≥ 1, and `1` when there's no climb.
    static func warmupStepBPM(working: Int, command: Int, intermediateSteps: Int) -> Int {
        let span = command - working
        guard span > 0 else { return 1 }
        let divisions = max(1, intermediateSteps + 1)
        return max(1, Int((Double(span) / Double(divisions)).rounded()))
    }

    /// How many intermediate plateaus a stored `stepBPM` stride implied between `working` and
    /// `command` — the one-time seed of an exercise's warm-up count from the stride it stored before
    /// ADR 0221 D4. `0` when the step jumps straight to command or there's no climb.
    static func intermediateSteps(working: Int, command: Int, stepBPM: Int) -> Int {
        let span = command - working
        guard span > 0, stepBPM > 0 else { return 0 }
        return max(0, Int((Double(span) / Double(stepBPM)).rounded()) - 1)
    }

    /// Whether the run summits above command — the reach is on and sits above it.
    var reachesAboveCommand: Bool { includeReach && target > command }

    /// The ordered plateaus, warm-up floor through backoff tail. Each phase's rungs hold that
    /// phase's own hold; the command plateau holds `dwellIntervals`. A phase that is switched off
    /// contributes nothing, and so does one with no room: no warm-up unless `command > working`, no
    /// summit unless `target > command`, no backoff unless it sits below command.
    var plateaus: [Plateau] {
        var result: [Plateau] = []
        if includeWarmup, command > working {
            let rungs = [working] + Self.intermediateBPMs(from: working, to: command, steps: warmupSteps)
            result += rungs.map { Plateau(bpm: $0, intervals: max(1, warmupHold)) }
        }
        result.append(Plateau(bpm: command, intervals: max(1, dwellIntervals)))
        if reachesAboveCommand {
            let rungs = Self.intermediateBPMs(from: command, to: target, steps: reachSteps) + [target]
            result += rungs.map { Plateau(bpm: $0, intervals: max(1, reachHold)) }
        }
        if includeBackoff {
            let backoff = backoffOverride
                ?? TempoStretch.backoffBPM(command: command, target: target, floor: working)
            if backoff < command {
                let summit = reachesAboveCommand ? target : command
                let rungs = Self.intermediateBPMs(from: summit, to: backoff, steps: backoffSteps) + [backoff]
                result += rungs.map { Plateau(bpm: $0, intervals: max(1, backoffHold)) }
            }
        }
        return result
    }

    /// Evenly-spaced BPMs strictly **between** `from` and `to` (both endpoints excluded), ordered
    /// from `from` toward `to` — `steps` of them, or as many as fit: the count is clamped by
    /// `rungs(steps:from:to:)`, so every stop is a distinct tempo and none lands on an endpoint.
    /// Works in both directions (ascending warm-up and reach, descending backoff). Empty when
    /// `steps ≤ 0` or there's no gap, so the caller always appends its own endpoint without
    /// duplication.
    static func intermediateBPMs(from: Int, to: Int, steps: Int) -> [Int] {
        let count = rungs(steps: steps, from: from, to: to) - 1
        guard count > 0 else { return [] }
        let span = Double(to - from)
        return (1...count).map { from + Int((span * Double($0) / Double(count + 1)).rounded()) }
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

    /// The index of the plateau the ramp is currently holding (the live-highlight cursor for
    /// the staircase, ADR 0046): the same walk as `bpm(…)` but returning the position, clamped
    /// to the last plateau once the ramp completes. `0` when there are no plateaus.
    func currentPlateauIndex(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Int {
        let steps = plateaus
        guard intervalCount > 0, !steps.isEmpty else { return 0 }
        let elapsed: Double = unit == .bars ? Double(max(0, elapsedBars)) : max(0, elapsedSeconds)
        let intervalsElapsed = Int(elapsed / Double(intervalCount))
        var cumulative = 0
        for (index, plateau) in steps.enumerated() {
            cumulative += plateau.intervals
            if intervalsElapsed < cumulative { return index }
        }
        return steps.count - 1
    }

    /// The boundary the ramp is approaching (ADR 0131): the plateau now holding, the one after it
    /// (`nil` at the ramp's end), and how far the boundary is in `unit`s.
    ///
    /// The same cumulative walk as `bpm(…)` and `currentPlateauIndex(…)`, deliberately — the warning
    /// and the change it warns about read one source, so they cannot disagree. Returns `nil` once the
    /// ramp has run out, where there is nothing left to approach.
    func pendingChange(elapsedBars: Double, elapsedSeconds: TimeInterval) -> PendingTempoChange? {
        let steps = plateaus
        guard intervalCount > 0, !steps.isEmpty else { return nil }
        let elapsed: Double = unit == .bars ? max(0, elapsedBars) : max(0, elapsedSeconds)
        var cumulative = 0
        for (index, plateau) in steps.enumerated() {
            cumulative += plateau.intervals
            let boundary = Double(cumulative * intervalCount)
            guard elapsed < boundary else { continue }
            return PendingTempoChange(
                from: plateau.bpm,
                to: index + 1 < steps.count ? steps[index + 1].bpm : nil,
                unitsRemaining: boundary - elapsed,
                plateauUnits: Double(plateau.intervals * intervalCount),
                unit: unit)
        }
        return nil
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
