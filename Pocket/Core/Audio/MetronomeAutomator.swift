import Foundation

/// Pure, UI-free tempo ramp for the **standalone** metronome (ADR 0043, slice 4) — the
/// sibling of the in-song `AutomatorConfig`. Both encode the same linear-ramp shape, but
/// where the loop trainer ramps a **speed multiple** keyed on **loop passes** (meaningless
/// for a song-less click), this ramps **absolute BPM** keyed on **elapsed bars or elapsed
/// seconds**: climb from `startBPM` toward `ceilingBPM` in `stepBPM` increments, one every
/// `intervalCount` units, then hold at the ceiling.
///
/// `unit` selects which elapsed quantity drives the ramp — **bars** (counted off the
/// generated beat sequence) or **seconds** (the session wall-clock). The engine supplies
/// both elapsed quantities each tick and this picks the relevant one, so the same value
/// type is exercised across both units (AGENTS.md: the stepping math has no UI coverage, so
/// it's pinned here). `stepBPM` is a positive magnitude; the direction is derived from the
/// sign of `ceilingBPM − startBPM`, so a ceiling below the start gives a **slow-down** ramp.
struct MetronomeAutomator: Equatable, TempoRamp {
    /// Whether the ramp is engaged. Disabled ⇒ the BPM never leaves `startBPM`.
    var enabled: Bool
    /// Where the ramp begins (absolute BPM) — the exercise's working tempo.
    var startBPM: Int
    /// BPM added (or removed) at each step. A positive magnitude; direction comes from the
    /// ceiling. Treated as "no ramp" when ≤ 0.
    var stepBPM: Int
    /// How many `unit`s between steps (every N bars / N seconds). Treated as "no ramp"
    /// when ≤ 0.
    var intervalCount: Int
    /// Whether the interval is counted in bars or seconds.
    var unit: MetronomeIntervalUnit
    /// Where the ramp holds (absolute BPM). Defaults, at the model layer, to the exercise's
    /// `targetTempo` so the ramp climbs toward the same goal the cross-session number tracks.
    var ceilingBPM: Int

    /// The tempo after `elapsedBars` bars and `elapsedSeconds` seconds of practice. Picks
    /// the elapsed quantity by `unit`, takes the number of completed intervals, and steps
    /// from `startBPM` toward `ceilingBPM`, clamped so it never overshoots the ceiling.
    func bpm(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Int {
        guard enabled, stepBPM > 0, intervalCount > 0, ceilingBPM != startBPM else { return startBPM }
        let elapsed: Double = unit == .bars ? Double(max(0, elapsedBars)) : max(0, elapsedSeconds)
        return tempo(atStep: Int(elapsed / Double(intervalCount)))
    }

    /// The tempo on plateau `step` of the climb, clamped so it never overshoots the ceiling in
    /// either direction. Shared by `bpm(…)` and `pendingChange(…)` so the tempo the ramp *will*
    /// step to is computed the same way as the tempo it steps to.
    private func tempo(atStep step: Int) -> Int {
        let direction = ceilingBPM > startBPM ? 1 : -1
        let raw = startBPM + direction * max(0, step) * stepBPM
        return min(max(raw, min(startBPM, ceilingBPM)), max(startBPM, ceilingBPM))
    }

    /// The next step of the climb and its distance (ADR 0131). Unlike `CommandRamp` the plateaus here
    /// are uniform — one `intervalCount` each, `stepsToCeiling` of them plus the ceiling's own hold —
    /// so the boundary is arithmetic rather than a walk. `nil` for a flat or disabled ramp (nothing is
    /// coming) and once the ceiling plateau has elapsed (the ramp is finished).
    func pendingChange(elapsedBars: Double, elapsedSeconds: TimeInterval) -> PendingTempoChange? {
        guard enabled, stepBPM > 0, intervalCount > 0, ceilingBPM != startBPM else { return nil }
        let elapsed: Double = unit == .bars ? max(0, elapsedBars) : max(0, elapsedSeconds)
        let interval = Double(intervalCount)
        let step = Int(elapsed / interval)
        guard step <= stepsToCeiling else { return nil }
        return PendingTempoChange(
            from: tempo(atStep: step),
            to: step < stepsToCeiling ? tempo(atStep: step + 1) : nil,
            unitsRemaining: Double(step + 1) * interval - elapsed,
            plateauUnits: interval,
            unit: unit)
    }

    /// Steps needed to reach the ceiling — for a "ramps to {ceiling} over {n} steps" readout.
    /// `0` when the ramp is flat (no step, or start already at the ceiling).
    var stepsToCeiling: Int {
        guard stepBPM > 0, ceilingBPM != startBPM else { return 0 }
        return Int((Double(abs(ceilingBPM - startBPM)) / Double(stepBPM)).rounded(.up))
    }

    /// Whether the ramp has reached (or holds at) the ceiling at the given elapsed.
    func hasReachedCeiling(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Bool {
        bpm(elapsedBars: elapsedBars, elapsedSeconds: elapsedSeconds) == ceilingBPM
    }

    /// The elapsed `unit`-count at which the ramp is **finished**: the ceiling plateau has
    /// been held for one full interval, like every other step (ADR 0043, slice 7) — so the
    /// engine can stop the click rather than hold at the ceiling forever. `nil` for a flat /
    /// disabled ramp (nothing to finish).
    var completionInterval: Int? {
        guard enabled, stepBPM > 0, intervalCount > 0, ceilingBPM != startBPM else { return nil }
        return (stepsToCeiling + 1) * intervalCount
    }

    /// Whether the ramp has finished — the ceiling plateau's interval has elapsed. Drives the
    /// auto-stop at the top of the climb.
    func isFinished(elapsedBars: Int, elapsedSeconds: TimeInterval) -> Bool {
        guard let completionInterval else { return false }
        let elapsed: Double = unit == .bars ? Double(max(0, elapsedBars)) : max(0, elapsedSeconds)
        return elapsed >= Double(completionInterval)
    }
}
