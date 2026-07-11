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

    /// Sparse landmarks a released gesture can always snap to: every marker plus every
    /// saved loop's start and end. `excluded` drops the loop being range-edited so its own
    /// edges don't capture the handle moving them. The **beat grid** is layered on top of
    /// these by `snapCandidates` — it's the dense candidate a free scrub deliberately drops
    /// (ADR 0080), so the sparse-landmark rule lives here, shared with the minimap.
    func landmarkCandidates(excluding excluded: Loop? = nil) -> [Double] {
        let markerFractions = duration > 0 ? markers.map { $0.seconds / duration } : []
        let loopEdges = loops
            .filter { $0.uid != excluded?.uid }
            .flatMap { [$0.start, $0.end] }
        return markerFractions + loopEdges
    }

    /// Fractions a released gesture can snap to: the sparse `landmarkCandidates` plus every
    /// **beat** of the grid when the song has one (ADR 0022 — so a loop edge or tap-seek can
    /// catch the pulse, not just markers/edges). Set `includingBeats: false` for a **free
    /// scrub**, which drops the dense grid so it lands where the finger lifts (ADR 0080).
    func snapCandidates(excluding excluded: Loop? = nil, includingBeats: Bool = true) -> [Double] {
        let beats = includingBeats ? beatGrid.map(\.fraction) : []
        return landmarkCandidates(excluding: excluded) + beats
    }

    /// The marker / loop-edge `fraction` should snap to, or `nil` if none is within
    /// `snapTolerance`. No side effects, so each release point decides its own haptic.
    func snapTarget(_ fraction: Double, excluding excluded: Loop? = nil) -> Double? {
        WaveformGesture.snap(fraction, to: snapCandidates(excluding: excluded), tolerance: snapTolerance)
    }

    /// Seek *release* on the detail waveform — seek, snapping the playhead to a nearby
    /// candidate with a light haptic on a catch. A **tap** ("take me to that structure")
    /// snaps to the full set: markers + loop edges + beats. A **scrub** ("put the playhead
    /// exactly here") snaps only to the sparse landmarks, dropping the beat grid so a
    /// deliberate scrub between beats lands where the finger lifts (ADR 0080) — the same
    /// candidate set the minimap uses. Separate from `seekToFraction` so the continuous
    /// scrub (`onChanged`) stays raw; this fires once, on release.
    func seekSnapping(_ fraction: Double, scrubbing: Bool = false) {
        let candidates = snapCandidates(includingBeats: !scrubbing)
        if let target = WaveformGesture.snap(fraction, to: candidates, tolerance: snapTolerance) {
            haptic(.light)
            seekToFraction(target)
        } else {
            seekToFraction(fraction)
        }
    }

    /// Minimap seek *release* — snap the playhead to a nearby **marker or saved-loop edge**
    /// with a light haptic on a catch, always excluding the beat grid: on the compressed
    /// full-song strip the beats pack too densely to land cleanly, whereas markers and loop
    /// edges are the sparse landmarks actually drawn there. Sources the same
    /// `landmarkCandidates` as a scrub release (ADR 0080), so the "sparse landmarks vs dense
    /// pulse" rule lives in one place. The live drag stays un-snapped; this fires on release.
    func seekMinimapSnapping(_ fraction: Double) {
        if let target = WaveformGesture.snap(fraction, to: landmarkCandidates(),
                                             tolerance: WaveformGesture.snapTolerance) {
            haptic(.light)
            seekToFraction(target)
        } else {
            seekToFraction(fraction)
        }
    }
}
