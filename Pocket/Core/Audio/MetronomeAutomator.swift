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
struct MetronomeAutomator: Equatable {
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
        let steps = Int(elapsed / Double(intervalCount))
        let direction = ceilingBPM > startBPM ? 1 : -1
        let raw = startBPM + direction * steps * stepBPM
        return min(max(raw, min(startBPM, ceilingBPM)), max(startBPM, ceilingBPM))
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
}
