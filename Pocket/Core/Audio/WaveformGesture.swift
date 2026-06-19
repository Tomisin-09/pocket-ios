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

    /// Tightest pinch-zoom: the smallest fraction of the song the detail waveform
    /// will show (≈20× zoom). `1` is the whole song (no zoom).
    static let minZoomSpan = 0.05

    /// Snap catch-radius as a fraction of the *visible* window (scaled by zoom span
    /// at the call site, like the Fine-handle grab zone, so it's a constant size on
    /// screen). Tighter than `handleTolerance` (0.06): snapping should assist precise
    /// placement, not hijack it. See `snap(_:to:tolerance:)` and ADR 0021.
    static let snapTolerance = 0.03

    /// Which loop boundary a Fine-mode touch is grabbing.
    enum Handle { case start, end }

    /// Clamp a zoom span (visible fraction of the song) to `minZoomSpan...1`.
    static func clampSpan(_ span: Double) -> Double {
        span.clamped(to: minZoomSpan...1)
    }

    /// **Page-mode** anchoring (ADR 0010): the visible window of width `span` holds
    /// still at `currentStart` while the playhead sweeps across it, then **pages** so
    /// the playhead stays visible. Returns the window start (a song fraction).
    ///
    /// - The window holds still while the playhead sits within `[start, start +
    ///   advanceThreshold·span]` (the comfortable zone, default to ~90% across).
    /// - When the playhead crosses that point — or is seeked outside the window
    ///   entirely (forward *or* back) — the window re-anchors so the playhead lands
    ///   `leadIn·span` in from the left edge, giving a little context behind it.
    /// - Always clamped to `0...(1 - span)`, so paging stops cleanly at the song ends.
    ///
    /// This supersedes the playhead-*centred* `viewport(center:span:)`: there the
    /// window slid under a pinned playhead every frame; here it only moves at page
    /// boundaries, so the playhead visibly travels and the envelope stays put.
    static func pagedStart(currentStart: Double, span: Double, playhead: Double,
                           advanceThreshold: Double = 0.9, leadIn: Double = 0.1) -> Double {
        let maxStart = Swift.max(0, 1 - span)
        let start = currentStart.clamped(to: 0...maxStart)
        guard span > 0 else { return start }
        let comfortable = playhead >= start && playhead <= start + advanceThreshold * span
        if comfortable { return start }
        return (playhead - leadIn * span).clamped(to: 0...maxStart)
    }

    /// Song fraction at the *centre* of bar `index` of a `count`-bar set that
    /// covers the song range `[coveredStart, coveredEnd]`. Used to place each
    /// waveform bar: the stored envelope covers `[0, 1]`; a crisp re-downsample
    /// covers just its zoomed window (ADR 0020). Centres (the `+ 0.5`) keep the
    /// bars symmetric within their slots. `count <= 0` returns `coveredStart`.
    static func barCentreFraction(index: Int, count: Int,
                                  coveredStart: Double, coveredEnd: Double) -> Double {
        guard count > 0 else { return coveredStart }
        return coveredStart + (Double(index) + 0.5) / Double(count) * (coveredEnd - coveredStart)
    }

    /// Map a `0...1` position on the *visible* waveform to a song fraction within
    /// `viewport`. (Inverse of `screenFraction`.)
    static func songFraction(screenFraction: Double, viewport: (start: Double, end: Double)) -> Double {
        viewport.start + screenFraction * (viewport.end - viewport.start)
    }

    /// Map a song fraction to its `0...1` position on the visible waveform. Falls
    /// outside `0...1` when the song fraction is off-screen (caller skips/clamps).
    static func screenFraction(songFraction: Double, viewport: (start: Double, end: Double)) -> Double {
        let span = viewport.end - viewport.start
        guard span > 0 else { return 0 }
        return (songFraction - viewport.start) / span
    }

    /// Map a horizontal position `point` (points) within a waveform of `width`
    /// points to a song fraction in `0...1`. Out-of-bounds touches clamp.
    static func fraction(atX point: Double, width: Double) -> Double {
        guard width > 0 else { return 0 }
        return (point / width).clamped(to: 0...1)
    }

    /// Order a long-press-drag selection's `anchor` and `current` points into
    /// bounds (`start <= end`), clamped to `0...1`. Unlike `loopBounds` this does
    /// **not** widen to a minimum width — the live drag region tracks the finger
    /// exactly, so you see precisely what you're selecting. Widening to
    /// `minLoopWidth` is applied only when the drag commits (`loopBounds`).
    static func selectionBounds(anchor: Double, current: Double) -> (start: Double, end: Double) {
        (Swift.min(anchor, current).clamped(to: 0...1),
         Swift.max(anchor, current).clamped(to: 0...1))
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

    /// Snap `fraction` to the nearest value in `candidates` when one lies within
    /// `tolerance` (all song fractions), else return `nil`. On gesture *release* this
    /// catches a loop edge, Fine handle, or tap-seek to a nearby marker or saved-loop
    /// boundary; `nil` lets the caller keep the raw fraction and skip the snap haptic.
    /// Candidates may be unsorted and may include duplicates; the nearest within range
    /// wins. A non-positive `tolerance` snaps only on an exact hit (ADR 0021).
    static func snap(_ fraction: Double, to candidates: [Double], tolerance: Double) -> Double? {
        var best: Double?
        var bestDistance = tolerance
        for candidate in candidates {
            let distance = abs(candidate - fraction)
            if distance <= bestDistance {
                best = candidate
                bestDistance = distance
            }
        }
        return best
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
