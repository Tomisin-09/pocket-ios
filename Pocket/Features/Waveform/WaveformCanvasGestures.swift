import SwiftUI

// The waveform's gesture recogniser, split out of `WaveformCanvas.swift` so the
// drawing and the gesture arbitration stay separate categories of code. One
// `DragGesture(minimumDistance: 0)` dispatched by mode, plus a simultaneous
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
                // A Fine handle grabbed by the first pinch finger: snap it back to where
                // it was grabbed and release it, so pinch-to-zoom never moves the bound.
                if let handle = grabbedHandle {
                    if let origin = grabbedHandleOrigin { onMoveHandle(handle, origin) }
                    grabbedHandle = nil
                    grabbedHandleOrigin = nil
                }
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
            if mode == .fine {
                let handle = pickHandle(at: fraction)
                grabbedHandle = handle
                // Remember where the handle started so a pinch taking over this touch
                // can snap it back (the first pinch finger would otherwise nudge it).
                grabbedHandleOrigin = fineSelection.map { handle == .start ? $0.start : $0.end }
            } else if canBeginSelection {        // navigate — start the hold-to-select timer
                startHold()
            }
        }
        // Already painting a selection — the drag extends it (no scrub).
        if isSelecting {
            onSelectChanged(fraction)
            return
        }
        let moved = abs(value.location.x - (dragStartX ?? value.location.x))
        applyModeDrag(fraction: fraction, moved: moved)
    }

    /// The mode-specific body of a continuing drag (extracted to keep `handleChanged`
    /// within the cyclomatic-complexity budget): navigate scrubs the playhead once the
    /// finger has moved past the threshold; Fine drags the grabbed handle.
    private func applyModeDrag(fraction: Double, moved: CGFloat) {
        switch mode {
        case .navigate:
            if didScrub || moved > scrubThreshold {     // a real drag scrubs the playhead
                didScrub = true
                cancelHold()                            // moved → it's a scrub, not a hold
                onScrub(fraction)
            } else {
                holdFraction = fraction                 // still holding — anchor where the finger is now
            }
        case .fine:
            if let grabbedHandle { onMoveHandle(grabbedHandle, fraction) }
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
        switch mode {
        case .navigate:
            // Seek-and-snap on release for BOTH a tap and a scrub. The live scrub in
            // `.onChanged` stayed raw (un-snapped) so it tracked the finger, but the
            // *release* catches the nearest marker / loop edge / beat. Previously only a
            // clean tap (≤ scrubThreshold) snapped; a tap that drifted past the threshold
            // fell through and never caught — the Navigate-mode gap behind ADR 0021's
            // catch (it worked in Fine mode via `endMoveHandle`). ADR 0021 amendment.
            onSeek(fraction)
        case .fine:
            if grabbedHandle != nil { onMoveHandleEnded() }   // audition the new bounds
            grabbedHandle = nil
            grabbedHandleOrigin = nil
        }
        dragStartX = nil
    }

    /// Whether a fresh navigate touch may arm a hold-to-select — only when no
    /// capture/forming region is already live (don't clobber a pending confirm).
    private var canBeginSelection: Bool {
        formingStart == nil && fineSelection == nil && tapSelection == nil
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

    /// Which Fine handle a touch grabs — defaults to `.start` when there's no
    /// selection yet, so the first drag always moves something.
    private func pickHandle(at fraction: Double) -> WaveformGesture.Handle {
        guard let fineSelection else { return .start }
        // Tolerance is a song fraction; scale by the zoom span so the grab zone
        // stays a constant size on screen.
        let tolerance = handleTolerance * (viewport.end - viewport.start)
        return WaveformGesture.nearestHandle(toFraction: fraction,
                                             start: fineSelection.start, end: fineSelection.end,
                                             tolerance: tolerance)
            ?? (abs(fraction - fineSelection.start) <= abs(fraction - fineSelection.end) ? .start : .end)
    }
}
