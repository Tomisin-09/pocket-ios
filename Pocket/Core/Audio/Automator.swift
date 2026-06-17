import Foundation

/// Pure, UI-free "speed trainer" config for a loop (ADR 0013): ramp playback speed up
/// in steps as you nail the loop — start slow, step up every few passes, hold at a
/// ceiling. Speed-based (× of original tempo), so it works even when the song's BPM is
/// unknown; `WaveformPracticeModel` applies it as the loop wraps.
///
/// Kept free of SwiftUI/AVFoundation so the stepping math is exhaustively unit-tested
/// (the house lesson: the logic with no UI coverage is exactly what breaks silently).
struct AutomatorConfig: Equatable {
    /// Where the ramp begins — the loop's start speed (× of original tempo).
    var startSpeed: Double
    /// How much to add at each step (×).
    var stepSpeed: Double
    /// The ceiling the ramp holds at once reached (×).
    var ceilingSpeed: Double
    /// Loop passes between steps (treated as ≥ 1).
    var repeatsPerStep: Int
    /// Whether the ramp is engaged.
    var enabled: Bool

    /// Playback speed at a given 0-based loop iteration: steps every `repeatsPerStep`
    /// passes by `stepSpeed`, holding at `ceilingSpeed`. A non-positive step or a
    /// ceiling at/below the start yields a flat ramp (start only). Always clamped to the
    /// engine's speed bounds.
    func speed(atLoopIteration iteration: Int) -> Double {
        guard stepSpeed > 0, ceilingSpeed > startSpeed else {
            return startSpeed.clamped(to: TempoMath.minSpeed...TempoMath.maxSpeed)
        }
        let stepIndex = max(0, iteration) / max(1, repeatsPerStep)
        let raw = startSpeed + Double(stepIndex) * stepSpeed
        return min(raw, ceilingSpeed).clamped(to: TempoMath.minSpeed...TempoMath.maxSpeed)
    }

    /// Number of steps from start to ceiling, inclusive of the start (≥ 1) — drives the
    /// setup popup's "N steps to target" readout. The epsilon absorbs float drift so an
    /// exact division (e.g. 0.30 / 0.05) doesn't round up to an extra phantom step.
    var stepCount: Int {
        guard stepSpeed > 0, ceilingSpeed > startSpeed else { return 1 }
        let steps = ((ceilingSpeed - startSpeed) / stepSpeed) - 1e-9
        return Int(steps.rounded(.up)) + 1
    }
}
