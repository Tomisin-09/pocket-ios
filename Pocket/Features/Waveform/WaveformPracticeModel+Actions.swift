import SwiftUI

// MARK: - Actions & gesture handlers

extension WaveformPracticeModel {

    /// Scroll-mode tap and Tap-mode scrub: move the playhead to a song fraction.
    func seekToFraction(_ fraction: Double) {
        engine.seek(toSeconds: fraction * duration)
    }

    /// Tap a marker in the list: seek the playhead to it.
    func seekToMarker(_ marker: WaveformMock.Marker) {
        engine.seek(toSeconds: marker.seconds)
        haptic(.light)
    }

    /// Scroll-mode hold: drop a marker at the held fraction, then open it to name.
    func dropMarker(_ fraction: Double) {
        let marker = WaveformMock.Marker(seconds: fraction * duration, label: "Marker")
        markers.append(marker)
        markers.sort { $0.seconds < $1.seconds }
        editingMarker = marker
    }

    /// Tap mode = punch in/out at the playhead; 1st plays on, 2nd stops + confirms.
    func tapPunch() {
        if let start = pendingStart {
            let bounds = WaveformGesture.loopBounds(start, playheadFraction)
            engine.pause()
            pendingStart = nil
            haptic(.medium)
            withAnimation(.easeOut(duration: 0.28)) {
                capture = CaptureDraft(start: bounds.start, end: bounds.end,
                                       fromFine: false, editingLoopID: nil)
            }
        } else {
            pendingStart = playheadFraction
            engine.play()
        }
    }

    /// Fine mode: drag a blue handle (bounds stay ordered + min-width apart).
    func moveFineHandle(_ handle: WaveformGesture.Handle, _ fraction: Double) {
        guard let current = capture else { return }
        let bounds = WaveformGesture.movingHandle(handle, toFraction: fraction,
                                                  start: current.start, end: current.end)
        capture = CaptureDraft(start: bounds.start, end: bounds.end,
                               fromFine: true, editingLoopID: current.editingLoopID)
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
                    capture = CaptureDraft(start: seed.0, end: seed.1, fromFine: true, editingLoopID: nil)
                }
            }
        case .scroll, .tap:
            if capture?.fromFine == true {
                withAnimation(.easeOut(duration: 0.2)) { capture = nil }
            }
        }
    }

    /// Confirm ✓ — write back a range edit, or open naming (capture kept so a discard can restore it).
    func confirmCapture() {
        guard let draft = capture else { return }
        if let id = draft.editingLoopID {
            if let index = loops.firstIndex(where: { $0.id == id }) {
                loops[index].start = draft.start
                loops[index].end = draft.end
            }
            activeLoopID = id
            applyActiveLoopToEngine()
            haptic(.medium)
            finishCapture()
        } else {
            namingDraft = NamingDraft(start: draft.start, end: draft.end)
        }
    }

    /// Confirm ✗ — discard the capture outright (and leave Fine).
    func cancelCapture() { finishCapture() }

    /// Clear the capture and leave Fine for the default Scroll mode.
    func finishCapture() {
        withAnimation(.easeOut(duration: 0.2)) {
            capture = nil
            if mode == .fine { mode = .scroll }
        }
    }

    /// Naming dismissed: Save consumed `capture`; survivor = Discard → keep Fine, drop Tap.
    func namingDismissed() {
        guard let draft = capture, !draft.fromFine else { return }
        withAnimation(.easeOut(duration: 0.2)) { capture = nil }
    }

    /// Naming-sheet Save — create the loop (empty name → range), then leave Fine.
    func saveNamed(_ name: String) {
        guard let draft = namingDraft else { return }
        let range = rangeString(draft.start, draft.end)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let loop = WaveformMock.Loop(name: trimmed.isEmpty ? range : trimmed,
                                     start: draft.start, end: draft.end,
                                     speed: speed, repeats: 4, duration: duration)
        loops.append(loop)
        activeLoopID = loop.id
        applyActiveLoopToEngine()
        capture = nil
        namingDraft = nil
        if mode == .fine { mode = .scroll }
    }

    /// "Adjust range" from a loop's edit sheet → Fine mode seeded with its bounds.
    func startRangeEdit(_ loop: WaveformMock.Loop) {
        capture = CaptureDraft(start: loop.start, end: loop.end, fromFine: true, editingLoopID: loop.id)
        withAnimation(.easeOut(duration: 0.2)) { mode = .fine }
    }

    func rangeString(_ start: Double, _ end: Double) -> String {
        "\(timecode(duration * start))–\(timecode(duration * end))"
    }

    /// A default loop span at the playhead, clamped so it never spills off the end.
    func defaultSelection() -> (Double, Double) {
        let start = min(playheadFraction, 0.85)
        return (start, min(start + 0.12, 0.98))
    }

    /// Set an unknown tempo — tap-tempo / manual entry is a follow-up (ADR 0004).
    func setBPM() {
        // TODO: present tap-tempo / manual BPM entry (see ADR 0004).
    }

    /// Tap a loop row: make it the active looping region, seek to start + play (active+playing → pause).
    func activate(_ loop: WaveformMock.Loop) {
        if activeLoopID == loop.id && engine.isPlaying {
            engine.pause()
        } else {
            activeLoopID = loop.id
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

    /// Keep the engine's loop region in sync with the active loop (or clear it).
    func applyActiveLoopToEngine() {
        if let activeLoop {
            engine.setLoop(start: activeLoop.startSeconds, end: activeLoop.endSeconds)
        } else {
            engine.clearLoop()
        }
    }

    func updateLoop(_ loop: WaveformMock.Loop) {
        guard let index = loops.firstIndex(where: { $0.id == loop.id }) else { return }
        loops[index] = loop
    }

    func deleteLoop(_ loop: WaveformMock.Loop) {
        loops.removeAll { $0.id == loop.id }
        if activeLoopID == loop.id {
            activeLoopID = loops.first?.id
            applyActiveLoopToEngine()
        }
    }

    func updateMarker(_ marker: WaveformMock.Marker) {
        guard let index = markers.firstIndex(where: { $0.id == marker.id }) else { return }
        markers[index] = marker
    }

    func deleteMarker(_ marker: WaveformMock.Marker) {
        markers.removeAll { $0.id == marker.id }
    }
}
