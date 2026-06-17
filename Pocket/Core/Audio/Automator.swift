import Foundation

/// Pure, UI-free "speed trainer" config for a loop (ADR 0013): ramp playback speed from a
/// **start** to a **target** over a chosen number of **steps**, advancing one step every
/// few loop **passes** — then hold at the target. The ramp climbs when target > start and
/// **descends** when target < start (a slow-down trainer). The user sets where (start →
/// target) and how granular (steps + loops-per-step); the per-step increment is *derived*.
/// Speed-based (× of original tempo) so it works even when the song's BPM is unknown.
///
/// Kept free of SwiftUI/AVFoundation so the stepping math is exhaustively unit-tested
/// (the house lesson: the logic with no UI coverage is exactly what breaks silently).
struct AutomatorConfig: Equatable {
    /// Where the ramp begins — the loop's start speed (× of original tempo).
    var startSpeed: Double
    /// Where the ramp ends and holds (×).
    var targetSpeed: Double
    /// How many steps to climb from start to target (treated as ≥ 1).
    var stepCount: Int
    /// Loop passes between steps (treated as ≥ 1).
    var loopsPerStep: Int
    /// Whether the ramp is engaged.
    var enabled: Bool

    /// Playback speed at a 0-based loop iteration: moves linearly from `startSpeed` to
    /// `targetSpeed` across `stepCount` steps (up or down), advancing one step every
    /// `loopsPerStep` passes and holding at the target. Intermediate speeds are rounded to
    /// 0.1% so they read cleanly; the final step lands exactly on the target. Clamped to
    /// engine bounds.
    func speed(atLoopIteration iteration: Int) -> Double {
        let bounds = TempoMath.minSpeed...TempoMath.maxSpeed
        guard abs(targetSpeed - startSpeed) > 1e-9, stepCount > 0 else {
            return startSpeed.clamped(to: bounds)
        }
        let stepIndex = min(max(0, iteration) / max(1, loopsPerStep), stepCount)
        if stepIndex >= stepCount { return targetSpeed.clamped(to: bounds) }
        let fraction = Double(stepIndex) / Double(stepCount)
        let raw = startSpeed + fraction * (targetSpeed - startSpeed)   // signed → ascends or descends
        let rounded = (raw * 1000).rounded() / 1000   // 0.1% precision
        return rounded.clamped(to: bounds)
    }

    /// The derived per-step increment (× units), **signed** — negative for a descending
    /// ramp; `0` when flat. The UI shows it as a signed percentage ("+5%" / "−5%").
    var stepSize: Double {
        guard abs(targetSpeed - startSpeed) > 1e-9, stepCount > 0 else { return 0 }
        return (targetSpeed - startSpeed) / Double(stepCount)
    }

    /// Total loop passes the ramp runs before playback stops. There are `stepCount + 1`
    /// plateaus — the start, each intermediate step, and the held target — and each plays
    /// `loopsPerStep` passes; once `loopIteration` reaches this count the loop has played
    /// its last automated pass and stops (ADR 0013). Components treated as ≥ 1.
    var totalLoops: Int {
        (max(0, stepCount) + 1) * max(1, loopsPerStep)
    }
}
