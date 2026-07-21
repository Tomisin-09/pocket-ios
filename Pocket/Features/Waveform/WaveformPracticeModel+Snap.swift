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

    /// Loop-edge release candidates with **per-candidate** tolerances (ADR 0099): markers and
    /// beats keep the full `snapTolerance`, but every *other* loop's edges yield — their catch
    /// radius shrinks to half the gap to the moving edge's grab origin (the edited loop's stored
    /// facing edge), so a facing neighbour in a tight gap stops hijacking the release while a
    /// roomy one still lines up. The edited loop's own edges are dropped (you don't snap a loop
    /// to itself). Loop-vs-loop softening only — markers/beats are untouched.
    func loopEdgeSnapCandidates(editing loop: Loop,
                                handle: WaveformGesture.Handle) -> [(value: Double, tolerance: Double)] {
        let base = snapTolerance
        let movingOrigin = handle == .start ? loop.start : loop.end
        let markerFractions = duration > 0 ? markers.map { $0.seconds / duration } : []
        var candidates = (markerFractions + beatGrid.map(\.fraction)).map { (value: $0, tolerance: base) }
        for other in loops where other.uid != loop.uid {
            for edge in [other.start, other.end] {
                let yielded = WaveformGesture.yieldedTolerance(base: base, gap: abs(edge - movingOrigin))
                candidates.append((value: edge, tolerance: yielded))
            }
        }
        return candidates
    }

    /// The fraction a range-edited loop edge should snap to under the neighbour-aware yield
    /// (ADR 0099), or `nil` if nothing catches within its (possibly-yielded) radius.
    func loopEdgeSnapTarget(_ fraction: Double, editing loop: Loop,
                            handle: WaveformGesture.Handle) -> Double? {
        WaveformGesture.snap(fraction, to: loopEdgeSnapCandidates(editing: loop, handle: handle))
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
