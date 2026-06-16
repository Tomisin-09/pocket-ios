import Foundation

/// Pure, UI-free geometry for the waveform gesture engine (design brief §4.1).
///
/// Translates horizontal touch positions on the waveform into song fractions
/// (`0...1`) and resolves loop bounds and Fine-mode handle hit-testing. Kept
/// free of SwiftUI/AVFoundation so this mapping — the slider-style logic that
/// breaks silently without coverage — is exhaustively unit-tested (AGENTS.md).
enum WaveformGesture {

    /// Smallest loop width, as a fraction of the song, a gesture may create.
    /// Stops a stray double-tap or a pinched Fine selection from making a
    /// zero-width loop.
    static let minLoopWidth = 0.02

    /// Which loop boundary a Fine-mode touch is grabbing.
    enum Handle { case start, end }

    /// Map a horizontal position `point` (points) within a waveform of `width`
    /// points to a song fraction in `0...1`. Out-of-bounds touches clamp.
    static func fraction(atX point: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return (point / width).clamped(to: 0...1)
    }

    /// Order two tapped fractions into a valid loop (`start < end`) and widen to
    /// `minWidth` if the points landed too close together, keeping the result
    /// inside `0...1`.
    static func loopBounds(_ first: Double, _ second: Double,
                           minWidth: Double = minLoopWidth) -> (start: Double, end: Double) {
        let lower = Swift.min(first, second).clamped(to: 0...1)
        let upper = Swift.max(first, second).clamped(to: 0...1)
        guard upper - lower < minWidth else { return (lower, upper) }
        // Too narrow — grow around the midpoint, then shove inside [0,1] if it
        // spilled over an edge.
        let mid = (lower + upper) / 2
        var start = mid - minWidth / 2
        var end = mid + minWidth / 2
        if start < 0 { start = 0; end = minWidth }
        if end > 1 { end = 1; start = 1 - minWidth }
        return (start, end)
    }

    /// Which handle a touch at fraction `point` is grabbing, or `nil` if neither
    /// is within `tolerance` (also a fraction). When both are in range the nearer
    /// one wins; ties resolve to `.start`.
    static func nearestHandle(toFraction point: Double, start: Double, end: Double,
                              tolerance: Double) -> Handle? {
        let dStart = abs(point - start)
        let dEnd = abs(point - end)
        guard Swift.min(dStart, dEnd) <= tolerance else { return nil }
        return dStart <= dEnd ? .start : .end
    }

    /// Move one handle to fraction `point`, keeping `start < end` separated by at
    /// least `minWidth` and clamped to `0...1`. The other handle stays put.
    static func movingHandle(_ handle: Handle, toFraction point: Double,
                             start: Double, end: Double,
                             minWidth: Double = minLoopWidth) -> (start: Double, end: Double) {
        let frac = point.clamped(to: 0...1)
        switch handle {
        case .start: return (Swift.min(frac, end - minWidth).clamped(to: 0...1), end)
        case .end:   return (start, Swift.max(frac, start + minWidth).clamped(to: 0...1))
        }
    }
}
