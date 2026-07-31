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

    /// `ramp` resized to fill roughly `minutes`, by **moving the dwell only** (ADR 0129).
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

        var fit = ramp
        fit.dwellIntervals = max(1, Int(((Double(minutes) * 60 - fixed) / perInterval).rounded()))
        return fit
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
