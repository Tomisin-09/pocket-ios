import Foundation

/// Maps the tempo slider's `0...1` track position to BPM on a **logarithmic** (perceptual)
/// scale (ADR 0043). A linear slider over a wide range (30…300) puts its midpoint at the
/// arithmetic centre (~165 BPM) and crams the musically common 60–120 zone into the left
/// fifth of the track — so a typical tempo *looks* slow. A log scale instead places the
/// **geometric** centre at the middle (√(30·300) ≈ 95 BPM) and gives 60–120 the centre of
/// the track, because tempo is perceived roughly logarithmically (each doubling is an
/// "octave" of feel): equal finger travel changes BPM by a roughly constant *ratio* — fine
/// control low, coarser high.
///
/// Pure and unit-tested (AGENTS.md — slider mapping is exactly the kind of logic that breaks
/// silently). Only the slider's position↔BPM binding uses this; the steppers and tap-tempo
/// still set absolute BPM directly.
enum TempoSliderScale {

    /// Track position (`0...1`, left→right) for a BPM, clamped into `range`.
    static func position(forBPM bpm: Int, in range: ClosedRange<Int>) -> Double {
        let lowerLog = log(Double(range.lowerBound))
        let upperLog = log(Double(range.upperBound))
        guard upperLog > lowerLog else { return 0 }
        let clamped = min(range.upperBound, max(range.lowerBound, bpm))
        return (log(Double(clamped)) - lowerLog) / (upperLog - lowerLog)
    }

    /// BPM for a track position, rounded to the nearest integer and clamped into `range`.
    static func bpm(forPosition position: Double, in range: ClosedRange<Int>) -> Int {
        let lowerLog = log(Double(range.lowerBound))
        let upperLog = log(Double(range.upperBound))
        let clampedPosition = min(1, max(0, position))
        let value = exp(lowerLog + clampedPosition * (upperLog - lowerLog))
        return min(range.upperBound, max(range.lowerBound, Int(value.rounded())))
    }
}
