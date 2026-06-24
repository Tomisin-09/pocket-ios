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

    /// Tap a marker in the list: seek the playhead to it and start playing from there
    /// (a marker is a "take me here and go" cue), so you hear the spot without a
    /// separate ▶ — same play-on-seek as a freshly created loop.
    func seekToMarker(_ marker: Marker) {
        engine.seek(toSeconds: marker.seconds)
        engine.play()
        haptic(.light)
    }

    /// Mark button — drop a marker at the playhead **instantly**, auto-named
    /// ("Marker 3", via pure `AutoName`) and persisted with no naming step; rename it
    /// later from its row (mirrors instant loop creation — ADR 0037, amending 0019).
    func dropMarkerAtPlayhead() {
        let label = AutoName.next(prefix: "Marker", existing: markers.map(\.label))
        let marker = Marker(seconds: playheadFraction * duration, label: label)
        context.insert(marker)
        marker.song = song          // attach → shows in `markers`, persists
        haptic(.medium)
    }

    // MARK: Hold-drag spatial A/B set (ADR 0041, secondary to play-along)

    /// A hold fired — anchor a new A/B span at the **playhead** and paint it out to
    /// `fraction` (the held point). Playhead-anchored (not the touch) so it matches the
    /// play-along set: A pins where playback is, the drag sets B. The A/B strip + handles
    /// stay back until release (`isDragSelecting`); the medium haptic confirms the switch
    /// from scrub to paint.
    func beginDragSelection(at fraction: Double) {
        abEditingLoop = nil                    // a spatial paint is a new span, not a loop edit
        if activeLoopID != nil { activeLoopID = nil }
        let anchor = playheadFraction          // A pins at the playhead; the drag sets B (ADR 0041)
        dragSelectAnchor = anchor
        isDragSelecting = true
        let bounds = WaveformGesture.selectionBounds(anchor: anchor, current: fraction)
        abSpan = .set(start: bounds.start, end: bounds.end)
        haptic(.medium)
    }

    /// The hold-drag moved — grow the A/B span from its anchor to `fraction`, exact
    /// (no min-width) so the region tracks the finger; min-width is enforced on release.
    func updateDragSelection(to fraction: Double) {
        guard let anchor = dragSelectAnchor, isDragSelecting else { return }
        let bounds = WaveformGesture.selectionBounds(anchor: anchor, current: fraction)
        abSpan = .set(start: bounds.start, end: bounds.end)
    }

    /// The hold-drag released — finalise the A/B span (widened to `minLoopWidth` if tiny,
    /// edges snapped to nearby markers / loop boundaries, ADR 0021) and loop it at once.
    /// The A/B strip (Save as loop · ✕) then appears — same living span as a play-along set.
    func endDragSelection() {
        guard let raw = abSpan.bounds, dragSelectAnchor != nil else { return }
        let snappedStart = snapTarget(raw.start) ?? raw.start
        let snappedEnd = snapTarget(raw.end) ?? raw.end
        let bounds = WaveformGesture.loopBounds(snappedStart, snappedEnd)
        abSpan = .set(start: bounds.start, end: bounds.end)
        dragSelectAnchor = nil
        isDragSelecting = false
        haptic(.medium)
        engine.setLoop(start: bounds.start * duration, end: bounds.end * duration)
        engine.seek(toSeconds: bounds.start * duration)
        engine.play()
    }

    /// Abort an in-progress hold-drag (e.g. a pinch took over) — drop the span.
    func cancelDragSelection() {
        dragSelectAnchor = nil
        isDragSelecting = false
        abSpan = .idle
        applyActiveLoopToEngine()
    }

    /// Create, persist, and activate a new loop with an auto name ("Loop 3"). No
    /// naming sheet — the range is visible on the waveform and it's renamed from the
    /// loop row (ADR 0019). Starts looping straight away (seek to start + play) so a
    /// freshly saved A/B span plays without a separate tap on ▶.
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

    /// "Adjust range" from a loop's edit sheet → lift the loop into the A/B span (ADR
    /// 0041) seeded with its bounds, looping it so you hear it while you drag the A/B
    /// handles; **Save changes** writes the new range back, ✕ discards. Activates the
    /// loop so it's the one playing.
    func startRangeEdit(_ loop: Loop) {
        activeLoopID = loop.uid
        applyActiveLoopToEngine()
        liftActiveLoopToSpan()
        engine.seek(toSeconds: loop.startSeconds)
        engine.play()
    }

    /// Tap a loop row: make it the active looping region, seek to start + play (active+playing → pause).
    /// Arming a *different* loop restores its last-practiced speed (ADR 0040); re-tapping the
    /// already-active loop only toggles play/pause, keeping the speed you're sitting at.
    func activate(_ loop: Loop) {
        abSpan = .idle                        // arming a saved loop drops any live A/B span
        if activeLoopID == loop.uid {
            if engine.isPlaying {
                engine.pause()
            } else {
                engine.seek(toSeconds: loop.startSeconds)
                engine.play()
            }
            return
        }
        activeLoopID = loop.uid               // didSet persists the outgoing loop's speed
        speed = loop.resumeSpeed              // restore this loop's last-practiced speed
        applyActiveLoopToEngine()
        engine.seek(toSeconds: loop.startSeconds)
        engine.play()
    }

    /// Exit-loop chip — stop looping and play on through the song.
    func clearActiveLoop() {
        activeLoopID = nil
        applyActiveLoopToEngine()
    }

    /// Keep the engine's loop region in sync with the active loop (or clear it).
    func applyActiveLoopToEngine() {
        if let activeLoop {
            engine.setLoop(start: activeLoop.startSeconds, end: activeLoop.endSeconds)
        } else {
            engine.clearLoop()
        }
    }

    // Loop / marker deletion + undo (ADR 0019) lives in `+Delete.swift`.
}
