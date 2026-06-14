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
        let p = position.clamped(to: 0...1)
        if p <= splitPosition {
            let t = p / splitPosition
            return minSpeed + t * (defaultSpeed - minSpeed)
        } else {
            let t = (p - splitPosition) / (1 - splitPosition)
            return defaultSpeed + t * (maxSpeed - defaultSpeed)
        }
    }

    /// Inverse of `speed(forPosition:)` — map a speed back to a slider position.
    static func position(forSpeed speed: Double) -> Double {
        let s = speed.clamped(to: minSpeed...maxSpeed)
        if s <= defaultSpeed {
            return splitPosition * (s - minSpeed) / (defaultSpeed - minSpeed)
        } else {
            return splitPosition + (1 - splitPosition) * (s - defaultSpeed) / (maxSpeed - defaultSpeed)
        }
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