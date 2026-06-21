import SwiftUI

// MARK: - Snap to markers & loop edges (ADR 0021)

// Split out of `WaveformPracticeModel+Actions.swift` for file length. On gesture
// *release* a loop edge, Fine handle, or tap-seek catches a nearby marker or saved
// loop boundary, so regions line up with the structure you can already see. The
// catch math is the pure, unit-tested `WaveformGesture.snap`; this file just sources
// the candidates, scales the tolerance to the zoom, and adds the light snap haptic.
extension WaveformPracticeModel {

    /// Snap catch-radius as a fraction of the *visible* window, so the zone stays a
    /// constant size on screen at any zoom (mirrors the canvas's handle grab).
    var snapTolerance: Double {
        WaveformGesture.snapTolerance * (viewport.end - viewport.start)
    }

    /// Fractions a released gesture can snap to: every marker, every saved loop's start
    /// and end, plus every **beat** of the grid when the song has one (ADR 0022 — so a
    /// loop edge or seek can catch the pulse, not just markers/edges). `excluded` drops
    /// the loop being range-edited so its own edges don't capture the handle moving them.
    func snapCandidates(excluding excluded: Loop? = nil) -> [Double] {
        let markerFractions = duration > 0 ? markers.map { $0.seconds / duration } : []
        let loopEdges = loops
            .filter { $0.uid != excluded?.uid }
            .flatMap { [$0.start, $0.end] }
        return markerFractions + loopEdges + beatGrid.map(\.fraction)
    }

    /// The marker / loop-edge `fraction` should snap to, or `nil` if none is within
    /// `snapTolerance`. No side effects, so each release point decides its own haptic.
    func snapTarget(_ fraction: Double, excluding excluded: Loop? = nil) -> Double? {
        WaveformGesture.snap(fraction, to: snapCandidates(excluding: excluded), tolerance: snapTolerance)
    }

    /// Tap-seek *release* — seek, snapping the playhead to a nearby marker / loop edge
    /// with a light haptic on a catch. Separate from `seekToFraction` so the
    /// continuous scrub and minimap stay un-snapped.
    func seekSnapping(_ fraction: Double) {
        if let target = snapTarget(fraction) {
            haptic(.light)
            seekToFraction(target)
        } else {
            seekToFraction(fraction)
        }
    }

    /// Minimap seek *release* — snap the playhead to a nearby **marker or saved-loop
    /// edge** with a light haptic on a catch. Excludes the **beat grid** (unlike the
    /// detail waveform's `seekSnapping`): on the compressed full-song strip the beats
    /// pack too densely to land cleanly, whereas markers and loop edges are the sparse
    /// landmarks actually drawn there. The live drag (`onChanged`) stays un-snapped so
    /// the scrub tracks the finger; this fires once, on release.
    func seekMinimapSnapping(_ fraction: Double) {
        let markerFractions = duration > 0 ? markers.map { $0.seconds / duration } : []
        let loopEdges = loops.flatMap { [$0.start, $0.end] }
        if let target = WaveformGesture.snap(fraction, to: markerFractions + loopEdges,
                                             tolerance: WaveformGesture.snapTolerance) {
            haptic(.light)
            seekToFraction(target)
        } else {
            seekToFraction(fraction)
        }
    }
}
