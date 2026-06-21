import SwiftData
import SwiftUI

// MARK: - Actions & gesture handlers

extension WaveformPracticeModel {

    /// Pinch-to-zoom: set how much of the song the waveform shows (clamped), then
    /// re-anchor the window so the playhead stays on screen at the new span.
    func setZoomSpan(_ span: Double) {
        zoomSpan = WaveformGesture.clampSpan(span)
        advancePageIfNeeded()
    }

    /// Page-mode (ADR 0010): hold the window still until the playhead sweeps to ~90%
    /// of it, then page so the playhead reappears near the left; also pages back if
    /// the playhead is seeked before the window. Driven by the playhead advancing
    /// (the view's `onChange`). Cheap: `viewportStart` only changes at page edges, so
    /// the envelope is redrawn on a flip, not every engine tick.
    func advancePageIfNeeded() {
        let newStart = WaveformGesture.pagedStart(
            currentStart: viewportStart, span: zoomSpan, playhead: playheadFraction)
        if abs(newStart - viewportStart) > 1e-9 { viewportStart = newStart }
    }

    /// Fit / 1× — reset the zoom to the whole song (the explicit reset affordance;
    /// double-tap is reserved for seek, ADR 0010).
    func resetZoom() {
        zoomSpan = 1
        viewportStart = 0
        haptic(.light)
    }

    // MARK: Crisp deep-zoom (ADR 0020)

    private static let detailSettle: Duration = .milliseconds(120)
    private static let detailCacheLimit = 24

    /// Re-downsample the visible window from the source file at full detail, so a deep
    /// zoom resolves real transients instead of stretched whole-song bars (ADR 0020).
    /// Driven by the view's `onChange` on the viewport (`zoomSpan` / `viewportStart`).
    /// Debounced so a continuous pinch or a burst of page flips coalesces into one
    /// read; cached by window so paging back reuses a prior read. Falls back to the
    /// stored `amplitudes` when zoomed out, when there's no source URL, or on failure.
    func scheduleDetailRefresh() {
        detailRefreshTask?.cancel()
        guard isZoomed, let url = sourceURL else {
            detailBars = nil
            return
        }
        let window = viewport
        let key = Self.windowKey(window)
        if let cached = detailCache[key] {
            detailBars = WaveformDetailBars(bars: cached, start: window.start, end: window.end)
            return
        }
        detailRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: Self.detailSettle)   // settle: coalesce a pinch / flip burst
            guard !Task.isCancelled else { return }
            let extracted = try? await Task.detached(priority: .userInitiated) {
                try WaveformExtractor.extractWindow(from: url,
                                                    startFraction: window.start, endFraction: window.end)
            }.value
            guard !Task.isCancelled, let self, let bars = extracted ?? nil else { return }
            cacheDetail(bars, key: key)
            // Only paint it if the viewport hasn't moved on since this read started.
            if Self.windowKey(viewport) == key {
                detailBars = WaveformDetailBars(bars: bars, start: window.start, end: window.end)
            }
        }
    }

    /// Quantise a window to ~0.1% so near-identical viewports share a cache entry.
    private static func windowKey(_ window: (start: Double, end: Double)) -> String {
        let start = (window.start * 1000).rounded() / 1000
        let span = ((window.end - window.start) * 1000).rounded() / 1000
        return "\(start)|\(span)"
    }

    /// Insert into the windowed-read cache, evicting the oldest beyond the cap.
    private func cacheDetail(_ bars: [Double], key: String) {
        if detailCache[key] == nil { detailCacheOrder.append(key) }
        detailCache[key] = bars
        while detailCacheOrder.count > Self.detailCacheLimit {
            detailCache.removeValue(forKey: detailCacheOrder.removeFirst())
        }
    }

    /// Scroll-mode tap and Tap-mode scrub: move the playhead to a song fraction. Used
    /// for *continuous* moves (scrub, minimap) where snapping would feel jumpy — the
    /// snapping variant `seekSnapping` is wired only to the tap-seek *release*.
    func seekToFraction(_ fraction: Double) {
        engine.seek(toSeconds: fraction * duration)
    }

    // Snap-to-marker/loop-edge helpers (`snapTarget`, `seekSnapping`, …) live in
    // `WaveformPracticeModel+Snap.swift` (ADR 0021), split out for file length.

    /// Tap a marker in the list: seek the playhead to it.
    func seekToMarker(_ marker: Marker) {
        engine.seek(toSeconds: marker.seconds)
        haptic(.light)
    }

    /// Mark button — start a new marker at the playhead. The name-only sheet adds it
    /// on save; cancelling discards it (so the sheet needs no position or delete).
    func dropMarkerAtPlayhead() {
        namingMarker = Marker(seconds: playheadFraction * duration, label: "")
    }

    /// Name-sheet Save for a new marker — persist it (empty name → "Marker").
    func saveMarkerName(_ name: String) {
        guard let marker = namingMarker else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        marker.label = trimmed.isEmpty ? "Marker" : trimmed
        context.insert(marker)
        marker.song = song          // attach → shows in `markers`, persists
        namingMarker = nil
    }

    /// Tap mode = punch in/out at the playhead; 1st plays on, 2nd closes the loop and
    /// **starts looping the punched region immediately** (no separate ▶), still as a
    /// draft you confirm with Y / discard with N.
    func tapPunch() {
        if let start = pendingStart {
            let bounds = WaveformGesture.loopBounds(start, playheadFraction)
            pendingStart = nil
            haptic(.medium)
            withAnimation(.easeOut(duration: 0.28)) {
                capture = CaptureDraft(start: bounds.start, end: bounds.end,
                                       fromFine: false, editingLoop: nil)
            }
            previewCapture()                              // arm the engine loop region…
            engine.seek(toSeconds: bounds.start * duration)
            engine.play()                                 // …and loop it at once, so the 2nd tap plays
        } else {
            pendingStart = playheadFraction
            engine.play()
        }
    }

    // MARK: Long-press-drag select (ADR 0005 round 5)

    /// A hold fired (navigate) — anchor a new green selection at the **playhead** and
    /// start painting it out to `fraction` (the held point). Anchoring at the playhead
    /// (not the touch) makes the hold-drag punch in where playback is, matching Tap-mode
    /// (`tapPunch`); the drag then sets the other end. The edit toolbar/transport lock
    /// stay back until release (`isDragSelecting`); the medium haptic confirms the switch
    /// from scrub to select. ADR 0005 (round 5, amended).
    func beginDragSelection(at fraction: Double) {
        guard capture == nil else { return }   // don't clobber a capture mid-confirm
        let anchor = playheadFraction
        dragSelectAnchor = anchor
        isDragSelecting = true
        let bounds = WaveformGesture.selectionBounds(anchor: anchor, current: fraction)
        capture = CaptureDraft(start: bounds.start, end: bounds.end, fromFine: false, editingLoop: nil)
        haptic(.medium)
    }

    /// The hold-drag moved — grow the selection from its anchor to `fraction`, exact
    /// (no min-width) so the region tracks the finger; min-width is enforced on release.
    func updateDragSelection(to fraction: Double) {
        guard let anchor = dragSelectAnchor, capture != nil else { return }
        let bounds = WaveformGesture.selectionBounds(anchor: anchor, current: fraction)
        capture = CaptureDraft(start: bounds.start, end: bounds.end, fromFine: false, editingLoop: nil)
    }

    /// The hold-drag released — finalise into a confirmable draft (widened to
    /// `minLoopWidth` if tiny) and audition it immediately (like a Loop punch).
    /// `showConfirm` flips true, raising the Y/N edit toolbar.
    func endDragSelection() {
        guard let draft = capture, dragSelectAnchor != nil else { return }
        // Snap each edge to a nearby marker / saved-loop boundary (ADR 0021). The
        // commit `haptic(.medium)` below is the catch feedback — no extra snap buzz.
        let snappedStart = snapTarget(draft.start) ?? draft.start
        let snappedEnd = snapTarget(draft.end) ?? draft.end
        let bounds = WaveformGesture.loopBounds(snappedStart, snappedEnd)
        capture = CaptureDraft(start: bounds.start, end: bounds.end, fromFine: false, editingLoop: nil)
        dragSelectAnchor = nil
        isDragSelecting = false
        haptic(.medium)
        previewCapture()
        engine.seek(toSeconds: bounds.start * duration)
        engine.play()
    }

    /// Abort an in-progress hold-drag (e.g. a pinch took over) — drop the draft.
    func cancelDragSelection() {
        dragSelectAnchor = nil
        isDragSelecting = false
        capture = nil
        applyActiveLoopToEngine()
    }

    /// Fine mode: drag a blue handle (bounds stay ordered + min-width apart).
    func moveFineHandle(_ handle: WaveformGesture.Handle, _ fraction: Double) {
        guard let current = capture else { return }
        lastFineHandle = handle          // remember which edge to snap on release
        let bounds = WaveformGesture.movingHandle(handle, toFraction: fraction,
                                                  start: current.start, end: current.end)
        capture = CaptureDraft(start: bounds.start, end: bounds.end,
                               fromFine: true, editingLoop: current.editingLoop)
        // Audio preview is committed on handle release (onMoveHandleEnded →
        // endMoveHandle), not per drag-frame — dragging only moves the handles.
    }

    /// Fine handle *release* — snap the just-moved edge to a nearby marker / loop
    /// boundary (excluding the loop being range-edited, so it doesn't catch its own
    /// edges), then audition the new bounds (ADR 0021). The other handle stays put;
    /// `movingHandle` keeps the min-width, so a snap can't collapse the loop.
    func endMoveHandle() {
        if let handle = lastFineHandle, let current = capture {
            let edge = handle == .start ? current.start : current.end
            if let target = snapTarget(edge, excluding: current.editingLoop) {
                let bounds = WaveformGesture.movingHandle(handle, toFraction: target,
                                                          start: current.start, end: current.end)
                capture = CaptureDraft(start: bounds.start, end: bounds.end,
                                       fromFine: true, editingLoop: current.editingLoop)
                haptic(.light)
            }
        }
        lastFineHandle = nil
        previewCapture()
    }

    /// Enter Fine → seed selection + pill; leave → drop unsaved; any switch clears a Tap capture.
    func modeChanged(to newMode: WaveformPracticeView.InteractionMode) {
        if pendingStart != nil {
            pendingStart = nil
            engine.pause()
        }
        switch newMode {
        case .fine:
            if capture?.fromFine != true {
                let seed = activeLoop.map { ($0.start, $0.end) } ?? defaultSelection()
                withAnimation(.easeOut(duration: 0.28)) {
                    capture = CaptureDraft(start: seed.0, end: seed.1, fromFine: true, editingLoop: nil)
                }
                previewCapture()   // arm the selection for audition / live preview
            }
        case .navigate:
            if capture?.fromFine == true {
                withAnimation(.easeOut(duration: 0.2)) { capture = nil }
                applyActiveLoopToEngine()   // drop the live preview, restore the saved loop
            }
        }
    }

    /// Confirm ✓ — write back a range edit, or create a new loop instantly (auto-named
    /// and activated, no naming step — rename later from its row; ADR 0019).
    func confirmCapture() {
        guard let draft = capture else { return }
        if let loop = draft.editingLoop {
            loop.start = draft.start          // mutating the @Model persists
            loop.end = draft.end
            activeLoopID = loop.uid
            applyActiveLoopToEngine()
        } else {
            createLoop(start: draft.start, end: draft.end)
        }
        haptic(.medium)
        finishCapture()
    }

    /// Create, persist, and activate a new loop with an auto name ("Loop 3"). No
    /// naming sheet — the range is visible on the waveform and it's renamed from the
    /// loop row (ADR 0019). Starts looping straight away (seek to start + play) so a
    /// freshly punched loop plays without a separate tap on ▶.
    func createLoop(start: Double, end: Double) {
        let name = AutoName.next(prefix: "Loop", existing: loops.map(\.name))
        let loop = Loop(name: name, start: start, end: end, speed: speed, repeats: 4)
        context.insert(loop)
        loop.song = song          // attach → shows in `loops`, persists
        activeLoopID = loop.uid
        applyActiveLoopToEngine()
        engine.seek(toSeconds: loop.startSeconds)
        engine.play()
    }

    /// Confirm ✗ — discard the capture outright (and leave Fine).
    func cancelCapture() { finishCapture() }

    /// Clear the capture and leave Fine for the default Scroll mode.
    func finishCapture() {
        withAnimation(.easeOut(duration: 0.2)) {
            capture = nil
            if mode == .fine { mode = .navigate }
        }
        applyActiveLoopToEngine()   // a discard reverts the live preview; a commit re-applies the same bounds
    }

    /// "Adjust range" from a loop's edit sheet → Fine mode seeded with its bounds.
    /// Activates the loop so it's the one you hear while refining it (and so a
    /// discard restores its original bounds).
    func startRangeEdit(_ loop: Loop) {
        activeLoopID = loop.uid
        capture = CaptureDraft(start: loop.start, end: loop.end, fromFine: true, editingLoop: loop)
        previewCapture()
        withAnimation(.easeOut(duration: 0.2)) { mode = .fine }
    }

    /// A default loop span at the playhead, clamped so it never spills off the end.
    func defaultSelection() -> (Double, Double) {
        let start = min(playheadFraction, 0.85)
        return (start, min(start + 0.12, 0.98))
    }

    /// Tap a loop row: make it the active looping region, seek to start + play (active+playing → pause).
    func activate(_ loop: Loop) {
        if activeLoopID == loop.uid && engine.isPlaying {
            engine.pause()
        } else {
            activeLoopID = loop.uid
            applyActiveLoopToEngine()
            engine.seek(toSeconds: loop.startSeconds)
            engine.play()
        }
    }

    /// Exit-loop chip — stop looping and play on through the song.
    func clearActiveLoop() {
        activeLoopID = nil
        applyActiveLoopToEngine()
    }

    /// Arm the engine loop to the in-progress capture (Tap or Fine) so it can be
    /// auditioned and — if playing — heard immediately. Reverting a discard is just
    /// `applyActiveLoopToEngine()`.
    func previewCapture() {
        guard let capture else { return }
        engine.setLoop(start: capture.start * duration, end: capture.end * duration)
    }

    /// The edit-toolbar ▶ — audition the captured region before saving. Toggles:
    /// pause if playing, else loop the capture from its start.
    func auditionCapture() {
        guard let capture else { return }
        if engine.isPlaying {
            engine.pause()
        } else {
            engine.setLoop(start: capture.start * duration, end: capture.end * duration)
            engine.seek(toSeconds: capture.start * duration)
            engine.play()
        }
    }

    /// Keep the engine's loop region in sync with the active loop (or clear it).
    func applyActiveLoopToEngine() {
        if let activeLoop {
            engine.setLoop(start: activeLoop.startSeconds, end: activeLoop.endSeconds)
        } else {
            engine.clearLoop()
        }
    }

    /// Delete a loop, with an Undo toast (ADR 0019). Edits to an existing loop are
    /// written straight to the @Model by its edit sheet (auto-persisting), so there's
    /// no `updateLoop`. Undo re-creates the loop from a snapshot (same uid + automator)
    /// and restores it as active if it was.
    func deleteLoop(_ loop: Loop) {
        let wasActive = activeLoopID == loop.uid
        let (uid, name) = (loop.uid, loop.name)
        let (start, end, lspeed, repeats) = (loop.start, loop.end, loop.speed, loop.repeats)
        let automator = loop.automator
        context.delete(loop)
        if wasActive {
            // Clean state (ADR 0029): deleting the loop you're hearing plays through
            // the song rather than silently arming a different saved region.
            activeLoopID = nil
            applyActiveLoopToEngine()
        }
        presentUndo("Deleted \(name)") { [weak self] in
            guard let self else { return }
            let restored = Loop(name: name, start: start, end: end, speed: lspeed, repeats: repeats)
            restored.uid = uid
            restored.automator = automator
            self.context.insert(restored)
            restored.song = self.song
            if wasActive {
                self.activeLoopID = restored.uid
                self.applyActiveLoopToEngine()
            }
        }
    }

    /// Delete a marker, with an Undo toast (ADR 0019). Undo re-creates it from a
    /// snapshot (same uid).
    func deleteMarker(_ marker: Marker) {
        let (uid, seconds, label) = (marker.uid, marker.seconds, marker.label)
        context.delete(marker)
        presentUndo("Deleted \(label)") { [weak self] in
            guard let self else { return }
            let restored = Marker(seconds: seconds, label: label)
            restored.uid = uid
            self.context.insert(restored)
            restored.song = self.song
        }
    }
}
