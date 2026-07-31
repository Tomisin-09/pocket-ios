import Foundation

/// Pure duration estimation for planner blocks (V2 planner R3): turn an exercise's **ramp
/// staircase** into real minutes instead of a flat default, so the planner's length readout and its
/// soft budget reflect what a session actually takes. Loops (region × repeats) and songs (duration)
/// already estimate in real time; this fills the exercise gap and the reps multiplier. Foundation-
/// only / unit-tested per AGENTS.md — the timing math is exactly the logic that drifts silently.
enum SessionEstimate {

    /// Seconds an exercise ramp takes to run once, integrating tempo **per plateau**. A bars-based
    /// ramp runs slower at the warm-up floor than at the reach, so a single flat BPM would
    /// misestimate — each plateau's bars are converted at that plateau's own BPM and the meter. A
    /// seconds-based ramp is already in real time (bars/meter irrelevant). Never negative.
    static func seconds(forRamp ramp: CommandRamp, beatsPerBar: Int) -> Double {
        let intervalCount = Double(max(1, ramp.intervalCount))
        switch ramp.unit {
        case .seconds:
            return Double(ramp.totalIntervals) * intervalCount
        case .bars:
            let beats = Double(max(1, beatsPerBar))
            return ramp.plateaus.reduce(0) { total, plateau in
                let bars = Double(plateau.intervals) * intervalCount
                let secondsPerBar = beats * 60.0 / Double(max(1, plateau.bpm))
                return total + bars * secondsPerBar
            }
        }
    }

    /// Whole minutes for one run of an exercise ramp (floored at 1), rounded from `seconds`.
    static func minutes(forRamp ramp: CommandRamp, beatsPerBar: Int) -> Int {
        minutes(fromSeconds: seconds(forRamp: ramp, beatsPerBar: beatsPerBar))
    }

    /// Whole minutes from a raw seconds duration, floored at 1 so a block never reads as "0 min".
    static func minutes(fromSeconds seconds: Double) -> Int {
        max(1, Int((seconds / 60).rounded()))
    }

    /// A per-block minute estimate scaled by its `reps` (R3): the single-run estimate times the
    /// repeat count, floored at 1. Reps below 1 are treated as a single run.
    static func minutes(perRun: Int, reps: Int) -> Int {
        max(1, perRun * max(1, reps))
    }

    // MARK: - Fitting a ramp to a block (ADR 0129)

    /// Seconds one **dwell interval** costs — `intervalCount` units held at the command tempo. The
    /// quantum the fit adds and removes.
    static func dwellIntervalSeconds(_ ramp: CommandRamp, beatsPerBar: Int) -> Double {
        let intervalCount = Double(max(1, ramp.intervalCount))
        switch ramp.unit {
        case .seconds:
            return intervalCount
        case .bars:
            let beats = Double(max(1, beatsPerBar))
            return intervalCount * beats * 60.0 / Double(max(1, ramp.command))
        }
    }

    /// How far the fit may shrink the **authored** dwell — half of what the player wrote.
    static let minDwellFitFactor = 0.5
    /// How far the fit may stretch the authored dwell (ADR 0129, amended after the device pass).
    ///
    /// Unbounded, the fit was an override rather than an adjustment: an exercise authored with a
    /// 4-interval dwell, given a 5-minute block, was stretched to **~19 intervals (~76 bars)** — five
    /// times what its author asked for, and enough to swamp the staircase. Sub-decision 3 kept the
    /// fit from *writing* the recipe and treated that as sufficient; it wasn't, because the run
    /// ignored the recipe anyway. A block may now stretch a dwell by up to 2.5×, and where that
    /// clamp bites the *block's estimate* gives way instead (see `effectiveMinutes`), so the session
    /// readout describes the ramp that will actually play.
    static let maxDwellFitFactor = 2.5

    /// `ramp` resized to fill roughly `minutes`, by **moving the dwell only** (ADR 0129) and never
    /// straying more than `minDwellFitFactor`…`maxDwellFitFactor` from the authored dwell.
    ///
    /// The exact inverse of `seconds(forRamp:beatsPerBar:)`: hold the warm-up, summit and backoff
    /// plateaus fixed — they are the staircase's shape, and stretching them would just make the climb
    /// languid — and pour the remaining budget into the command plateau, where consolidation actually
    /// happens. The resulting dwell share is therefore *emergent*, not enforced: an exercise with a
    /// long staircase keeps more of its slot in the climb, one with a short staircase spends almost
    /// all of it at command. In practice it lands around 65–75%.
    ///
    /// The dwell floors at 1 — the command plateau must hold — so a slot too short to contain even the
    /// fixed plateaus yields the shortest legal ramp rather than a truncated or empty one. A
    /// non-positive `minutes` returns the ramp untouched.
    ///
    /// Pure, and deliberately **not** a mutation of the stored recipe: the caller hands the result to a
    /// run, it never writes back to the `Exercise` (ADR 0129 sub-decision 3).
    static func fitted(_ ramp: CommandRamp, toMinutes minutes: Int, beatsPerBar: Int) -> CommandRamp {
        guard minutes > 0 else { return ramp }
        let perInterval = dwellIntervalSeconds(ramp, beatsPerBar: beatsPerBar)
        guard perInterval > 0 else { return ramp }

        // Everything that isn't dwell, measured by pricing a one-interval dwell and removing it.
        var probe = ramp
        probe.dwellIntervals = 1
        let fixed = seconds(forRamp: probe, beatsPerBar: beatsPerBar) - perInterval

        let wanted = Int(((Double(minutes) * 60 - fixed) / perInterval).rounded())
        var fit = ramp
        fit.dwellIntervals = clampedDwell(wanted, authored: ramp.dwellIntervals)
        return fit
    }

    /// A fitted dwell held within reach of the `authored` one. The lower bound floors at 1 (the
    /// command plateau must hold) and the upper bound never falls below it, so the range is always
    /// non-empty however short the authored dwell.
    static func clampedDwell(_ wanted: Int, authored: Int) -> Int {
        let base = Double(max(1, authored))
        let lower = max(1, Int((base * minDwellFitFactor).rounded()))
        let upper = max(lower, Int((base * maxDwellFitFactor).rounded()))
        return min(upper, max(lower, wanted))
    }

    /// What a block **actually takes** once its ramp has been fitted to `minutes` — the honest figure
    /// wherever a length is displayed or summed.
    ///
    /// It equals the allotted `minutes` while the fit can reach them, and departs from it exactly when
    /// the dwell clamp bites: a 5-minute slot given a short authored staircase plays for as long as
    /// 2.5× that staircase takes, and says so, rather than promising five minutes of practice it will
    /// not deliver. `nil` minutes (a hand-authored block) is just the ramp's own natural length.
    static func effectiveMinutes(forRamp ramp: CommandRamp, plannedMinutes: Int?,
                                 beatsPerBar: Int) -> Int {
        guard let plannedMinutes else { return minutes(forRamp: ramp, beatsPerBar: beatsPerBar) }
        return minutes(forRamp: fitted(ramp, toMinutes: plannedMinutes, beatsPerBar: beatsPerBar),
                       beatsPerBar: beatsPerBar)
    }

    /// How a session's estimate sits against the chosen length — a **soft** budget (R3). Within
    /// ±`tolerance` of the target reads on-target; below/above reads under/over. Never a hard gate:
    /// the planner always generates a session, this only *labels* the fit on the review screen.
    enum Fit: Equatable { case under, onTarget, over }

    /// Classify `estimate` against `target` (both minutes). A non-positive target reads on-target
    /// (no budget to miss). Default tolerance is ±15%.
    static func fit(estimateMinutes estimate: Int, targetMinutes target: Int,
                    tolerance: Double = 0.15) -> Fit {
        guard target > 0 else { return .onTarget }
        let lower = Double(target) * (1 - tolerance)
        let upper = Double(target) * (1 + tolerance)
        if Double(estimate) < lower { return .under }
        if Double(estimate) > upper { return .over }
        return .onTarget
    }
}
