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
