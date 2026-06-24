import SwiftUI

// The waveform's gesture recogniser, split out of `WaveformCanvas.swift` so the
// drawing and the gesture arbitration stay separate categories of code. One
// `DragGesture(minimumDistance: 0)`, plus a simultaneous
// `MagnifyGesture` for pinch-zoom — ADR 0005 (rounds 4–5). All math is in the
// pure, unit-tested `WaveformGesture`; this file is just the touch plumbing and
// the cross-gesture arbitration (tap · scrub · hold-drag select · pinch).

extension WaveformView {

    /// Pinch to set the zoom span — `MagnifyGesture` (iOS 17+). The span at pinch
    /// start is captured so the magnification scales it directly.
    var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                didPinch = true   // latched until the drag's onEnded clears it (ordering: magnify ends first)
                // A second finger means zoom, not select: kill any pending hold and
                // abort a selection that already armed in the gap before recognition.
                cancelHold()
                if isSelecting { isSelecting = false; onSelectCancelled() }
                // An A/B handle grabbed by the first pinch finger: snap a *committed* drag
                // back to where it was grabbed and release it, so pinch never moves the
                // bound; a merely-pended grab just drops.
                if let handle = grabbedHandle, let origin = grabbedHandleOrigin {
                    onMoveABHandle(handle, origin)
                }
                grabbedHandle = nil
                grabbedHandleOrigin = nil
                pendingGrab = nil
                let base = pinchBaseSpan ?? (viewport.end - viewport.start)
                pinchBaseSpan = base
                onSetZoomSpan(WaveformGesture.clampSpan(base / value.magnification))
            }
            // Leave `didPinch` set — magnify.onEnded fires *before* drag.onEnded, so
            // the drag uses it to swallow the trailing phantom tap, then clears it.
            .onEnded { _ in pinchBaseSpan = nil }
    }

    func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in handleChanged(value, width: width) }
            .onEnded { value in handleEnded(value, width: width) }
    }

    private func handleChanged(_ value: DragGesture.Value, width: CGFloat) {
        if dragStartX == nil, pinchBaseSpan == nil { didPinch = false }   // fresh touch — clear any stale pinch latch
        guard pinchBaseSpan == nil, !didPinch else { return }   // ignore the drag while/after pinching
        let fraction = songFraction(atX: value.location.x, width: width)
        // Setting the 1 (ADR 0024): the whole surface places the downbeat handle —
        // any drag/tap moves it (snapped on release), nothing seeks or selects.
        if downbeatDraft != nil {
            dragStartX = value.startLocation.x
            onDownbeatMove(fraction)
            return
        }
        if dragStartX == nil {
            dragStartX = value.startLocation.x
            didScrub = false
            holdFraction = fraction
            onTouchBegan()   // arm the swipe-back guard for this touch (ADR 0030)
            // Touching an edge only *pends* a grab — a tap seeks, a drag moves the edge
            // (committed in `applyDrag` past the scrub threshold), so the playhead can be
            // moved inside a loop without nudging a handle (ADR 0041).
            if let handle = pickABHandle(at: fraction) {          // an A/B span edge
                pendingGrab = (handle, false)
                grabbedHandleOrigin = abSelection.map { handle == .start ? $0.start : $0.end }
            } else if let handle = pickLoopEdge(at: fraction) {   // the active loop's edge → lift into A/B
                pendingGrab = (handle, true)
                grabbedHandleOrigin = loop.map { handle == .start ? $0.start : $0.end }
            } else if canBeginSelection {                         // start the hold-to-set timer
                startHold()
            }
        }
        // Already painting a hold-drag A/B span — the drag extends it (no scrub).
        if isSelecting {
            onSelectChanged(fraction)
            return
        }
        let moved = abs(value.location.x - (dragStartX ?? value.location.x))
        applyDrag(fraction: fraction, moved: moved)
    }

    /// The body of a continuing drag: move a grabbed A/B edge (committing a pended grab
    /// once the finger crosses the threshold — lifting a saved loop first), else scrub the
    /// playhead past the threshold (a still finger arms a hold-to-set).
    private func applyDrag(fraction: Double, moved: CGFloat) {
        if let pending = pendingGrab {
            guard didScrub || moved > scrubThreshold else { return }   // still a tap — don't move the edge
            if grabbedHandle == nil {                   // first real movement — commit the grab
                if pending.lift { onLiftLoopEdge() }    // a saved-loop edge: lift it into A/B now
                grabbedHandle = pending.handle
                didScrub = true
            }
            onMoveABHandle(pending.handle, fraction)
        } else if didScrub || moved > scrubThreshold {  // a real drag scrubs the playhead
            didScrub = true
            cancelHold()                                // moved → it's a scrub, not a hold
            onScrub(fraction)
        } else {
            holdFraction = fraction                     // still holding — anchor where the finger is now
        }
    }

    private func handleEnded(_ value: DragGesture.Value, width: CGFloat) {
        cancelHold()
        onTouchEnded()   // release the swipe-back guard, whatever path this gesture took (ADR 0030)
        // A pinch this touch sequence — swallow the lift-off tap/scrub, then reset
        // the latch for the next gesture. (Fixes pinch-zoom firing a phantom seek.)
        if didPinch || pinchBaseSpan != nil {
            didPinch = false
            grabbedHandle = nil
            grabbedHandleOrigin = nil
            pendingGrab = nil
            isSelecting = false
            dragStartX = nil
            return
        }
        // Setting the 1 (ADR 0024) — snap the placed downbeat to the nearest peak.
        if downbeatDraft != nil {
            onDownbeatEnded()
            dragStartX = nil
            return
        }
        // A long-press-drag selection — commit it (release order: timer already
        // cancelled above; pinch can't be active here).
        if isSelecting {
            onSelectEnded()
            isSelecting = false
            dragStartX = nil
            return
        }
        let fraction = songFraction(atX: value.location.x, width: width)
        if let grabbedHandle {               // a committed A/B-edge drag — snap + re-loop, no seek
            onMoveABHandleEnded(grabbedHandle)
            self.grabbedHandle = nil
            grabbedHandleOrigin = nil
            pendingGrab = nil
            dragStartX = nil
            return
        }
        // Seek-and-snap on release for a tap or scrub — *including* a tap that started on a
        // loop edge (a pended grab that never moved): the edge stays put, the playhead moves
        // there. The live scrub stayed raw so it tracked the finger; the release catches the
        // nearest marker / loop edge / beat (ADR 0021 amendment).
        pendingGrab = nil
        grabbedHandleOrigin = nil
        onSeek(fraction)
        dragStartX = nil
    }

    /// Whether a fresh touch may arm a hold-to-set A/B paint — only when nothing is
    /// already live on the waveform (don't clobber a forming A or an existing span).
    private var canBeginSelection: Bool {
        formingStart == nil && tapSelection == nil && abSelection == nil
    }

    /// Which A/B span handle a navigate touch grabs (ADR 0041), or `nil` when no span is
    /// set or the touch is away from both edges — so a touch mid-span still seeks /
    /// scrubs / holds. Tolerance scales with zoom like the Fine grab zone.
    private func pickABHandle(at fraction: Double) -> WaveformGesture.Handle? {
        guard let abSelection else { return nil }
        let tolerance = handleTolerance * (viewport.end - viewport.start)
        return WaveformGesture.nearestHandle(toFraction: fraction,
                                             start: abSelection.start, end: abSelection.end,
                                             tolerance: tolerance)
    }

    /// Which edge of the **active loop** a navigate touch grabs to lift it into A/B for a
    /// direct range edit (ADR 0041), or `nil` when no loop is active, a span/capture is
    /// already live, or the touch is away from both edges. Tolerance scales with zoom.
    private func pickLoopEdge(at fraction: Double) -> WaveformGesture.Handle? {
        guard abSelection == nil, tapSelection == nil, formingStart == nil, let loop else { return nil }
        let tolerance = handleTolerance * (viewport.end - viewport.start)
        return WaveformGesture.nearestHandle(toFraction: fraction,
                                             start: loop.start, end: loop.end, tolerance: tolerance)
    }

    /// Start the still-hold timer; firing arms a selection at the held fraction.
    /// Cancelled by movement (a scrub), release, or a pinch taking over.
    private func startHold() {
        cancelHold()
        longPressTask = Task { @MainActor in
            try? await Task.sleep(for: longPressDuration)
            guard !Task.isCancelled else { return }
            armSelection()
        }
    }

    private func cancelHold() {
        longPressTask?.cancel()
        longPressTask = nil
    }

    /// The hold fired — switch from scrub to select. Re-checks the guards in case
    /// state changed between scheduling and firing.
    @MainActor private func armSelection() {
        guard dragStartX != nil, !isSelecting, !didScrub, !didPinch,
              pinchBaseSpan == nil, canBeginSelection else { return }
        isSelecting = true
        onSelectBegan(holdFraction)
    }
}
