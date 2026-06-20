import Foundation

/// Pure, UI-free tempo + speed-slider math.
///
/// Kept deliberately free of SwiftUI/AVFoundation so it can be exhaustively
/// unit-tested (the Docket lesson: the logic with no UI coverage is exactly the
/// logic that breaks silently). Everything here is a static, deterministic
/// function of its inputs.
enum TempoMath {

    /// Playback speed bounds (× of original tempo).
    static let minSpeed = 0.25
    static let maxSpeed = 2.0
    static let defaultSpeed = 1.0

    /// Fraction of the slider track occupied by the slow segment (0.25×–1.0×).
    /// Asymmetric on purpose: slow practice is the primary use case, so 1.0×
    /// sits slightly left of centre and the slow range gets more precision.
    static let splitPosition = 0.54

    /// Effective BPM at a given speed: `round(songBPM × speed)`.
    /// Rounds half away from zero, so 85 BPM × 0.50× = 42.5 → 43 (per brief).
    static func effectiveBPM(songBPM: Int, speed: Double) -> Int {
        Int((Double(songBPM) * speed).rounded())
    }

    /// Map a slider position in `0...1` to a playback speed in `0.25...2.0`,
    /// using the two-segment asymmetric scale.
    static func speed(forPosition position: Double) -> Double {
        let pos = position.clamped(to: 0...1)
        if pos <= splitPosition {
            let frac = pos / splitPosition
            return minSpeed + frac * (defaultSpeed - minSpeed)
        } else {
            let frac = (pos - splitPosition) / (1 - splitPosition)
            return defaultSpeed + frac * (maxSpeed - defaultSpeed)
        }
    }

    /// Inverse of `speed(forPosition:)` — map a speed back to a slider position.
    static func position(forSpeed speed: Double) -> Double {
        let spd = speed.clamped(to: minSpeed...maxSpeed)
        if spd <= defaultSpeed {
            return splitPosition * (spd - minSpeed) / (defaultSpeed - minSpeed)
        } else {
            return splitPosition + (1 - splitPosition) * (spd - defaultSpeed) / (maxSpeed - defaultSpeed)
        }
    }

    /// Musical bounds for a tapped tempo. A double-tap or a long pause would
    /// otherwise yield an absurd BPM; clamping keeps the result usable (ADR 0024).
    static let minTapBPM = 30.0
    static let maxTapBPM = 300.0

    /// BPM inferred from a series of tap timestamps in **song-time seconds**,
    /// ascending. Averages the inter-tap intervals, discarding any non-positive
    /// gap — a tap whose loop wrapped playback back to an earlier song position
    /// straddles the boundary and can't measure tempo (ADR 0024). Returns `nil`
    /// with fewer than two usable taps; clamps the result to `minTapBPM...maxTapBPM`.
    /// Capturing song-time (not wall-clock) is what makes tapping inside a loop or
    /// at a reduced speed read the song's true tempo automatically.
    static func bpm(fromTapTimes times: [TimeInterval]) -> Double? {
        guard times.count >= 2 else { return nil }
        var intervals: [TimeInterval] = []
        for index in 1..<times.count {
            let gap = times[index] - times[index - 1]
            if gap > 0 { intervals.append(gap) }
        }
        guard !intervals.isEmpty else { return nil }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return nil }
        return (60.0 / mean).clamped(to: minTapBPM...maxTapBPM)
    }

    /// Number of discrete steps a tempo automator will take from start to
    /// ceiling, inclusive of the starting BPM. A non-positive step yields a
    /// single (start-only) step rather than diverging.
    static func automatorStepCount(startBPM: Int, stepBPM: Int, ceilingBPM: Int) -> Int {
        guard stepBPM > 0, ceilingBPM > startBPM else { return 1 }
        return (ceilingBPM - startBPM + stepBPM - 1) / stepBPM + 1
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
