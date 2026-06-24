import SwiftUI

// MARK: - A/B span — the loop-creation primitive (ADR 0041)
//
// The ephemeral A↔B span replaces the punch-to-draft commit gate. Play along and
// tap the Loop control: first tap drops A at the playhead, the second closes the
// span and loops A↔B immediately, a third clears it. The span lives with no ✗/✓ —
// audition and rehearse freely, then **Save as loop** promotes it (auto-named,
// activated; ADR 0019) or **✕** clears it and plays on through. The pure cycle is
// `ABSpan`; this wires it to the engine and the saved-loop store.

extension WaveformPracticeModel {

    /// True while a span is in play (forming A, or a closed A↔B) — drives the A/B
    /// strip and lights the Loop control.
    var abActive: Bool { abSpan != .idle }

    /// True while the span is a *saved* loop lifted in for a range edit — the strip
    /// reads "Save changes" (write-back) rather than "Save as loop" (create new).
    var isEditingSpan: Bool { abEditingLoop != nil }

    /// The A/B strip caption: a "set B" prompt while forming; the span's times once set,
    /// prefixed with the loop name while range-editing a saved loop.
    var abSpanLabel: String {
        switch abSpan {
        case .idle:
            return ""
        case .armed:
            return "Tap Loop again to set the end"
        case .set(let start, let end):
            let times = "\(timecode(start * duration)) – \(timecode(end * duration))"
            return abEditingLoop.map { "\($0.name) · \(times)" } ?? times
        }
    }

    /// The forming-A marker to render on the waveform — a play-along A awaiting B.
    var formingMarker: Double? { abSpan.armedPoint }

    /// The green span region to render (wash) — the live A/B span.
    var greenSpan: (start: Double, end: Double)? { abSpan.bounds }

    /// Play-along set (ADR 0041): advance the A/B cycle at the playhead. Drop A and
    /// run free so B can be found by ear; close the span and loop it at once; or
    /// clear and play on through. Clears any in-flight Tap/Fine capture so the two
    /// creation surfaces never fight.
    func tapAB() {
        abEditingLoop = nil          // a fresh play-along span is a new loop, not an edit
        let next = abSpan.tappingPlayhead(playheadFraction)
        abSpan = next
        switch next {
        case .armed:
            if activeLoopID != nil { activeLoopID = nil }
            engine.clearLoop()        // run free — listen forward for B
            engine.play()
            haptic(.medium)
        case .set(let start, let end):
            engine.setLoop(start: start * duration, end: end * duration)
            engine.seek(toSeconds: start * duration)
            engine.play()             // loop A↔B immediately, so the 2nd tap plays
            haptic(.medium)
        case .idle:
            applyActiveLoopToEngine() // span cleared by the cycle — revert to full song
            haptic(.light)
        }
    }

    /// ✕ — clear the span and play on through the song. A range edit is discarded
    /// (the saved loop keeps its original bounds — write-back only happens on Save).
    func clearABSpan() {
        abSpan = .idle
        abEditingLoop = nil
        applyActiveLoopToEngine()
        haptic(.light)
    }

    /// "Save as loop" / "Save changes" — write the closed span back to the loop being
    /// range-edited, or promote it to a new auto-named, activated loop (ADR 0019/0041).
    func saveABSpan() {
        guard case .set(let start, let end) = abSpan else { return }
        if let loop = abEditingLoop {
            loop.start = start          // mutating the @Model persists the new range
            loop.end = end
            abSpan = .idle
            abEditingLoop = nil
            activeLoopID = loop.uid
            applyActiveLoopToEngine()
        } else {
            abSpan = .idle
            createLoop(start: start, end: end)   // inserts, activates, seeks + plays
        }
        haptic(.medium)
    }

    /// Lift the active loop into the A/B span for a direct edge edit (ADR 0041): seed the
    /// span with its bounds and mark it the edit target. Triggered by grabbing the loop's
    /// edge on the waveform; the drag then refines it and Save writes the new range back.
    func liftActiveLoopToSpan() {
        guard let loop = activeLoop else { return }
        abEditingLoop = loop
        abSpan = .set(start: loop.start, end: loop.end)
    }

    /// Drag an A/B span edge in place (ADR 0041) — the same handle mechanics as Fine,
    /// but on the live span and with no mode hop. Bounds stay ordered and `minLoopWidth`
    /// apart; the engine loop re-arms on release (`endABHandle`), not per drag-frame.
    func moveABHandle(_ handle: WaveformGesture.Handle, _ fraction: Double) {
        guard case .set(let start, let end) = abSpan else { return }
        let bounds = WaveformGesture.movingHandle(handle, toFraction: fraction, start: start, end: end)
        abSpan = .set(start: bounds.start, end: bounds.end)
    }

    /// A/B `handle` release — snap the moved edge to a nearby marker / loop boundary
    /// (ADR 0021), then re-arm the engine loop to the new span (no playhead yank).
    func endABHandle(_ handle: WaveformGesture.Handle) {
        guard case .set(let start, let end) = abSpan else { return }
        if let target = snapTarget(handle == .start ? start : end) {
            let bounds = WaveformGesture.movingHandle(handle, toFraction: target, start: start, end: end)
            abSpan = .set(start: bounds.start, end: bounds.end)
            haptic(.light)
        }
        if case .set(let newStart, let newEnd) = abSpan {
            engine.setLoop(start: newStart * duration, end: newEnd * duration)
        }
    }

    /// The A/B strip ▶ — audition the closed span. Pause if playing, else loop it from A.
    func auditionABSpan() {
        guard case .set(let start, let end) = abSpan else { return }
        if engine.isPlaying {
            engine.pause()
        } else {
            engine.setLoop(start: start * duration, end: end * duration)
            engine.seek(toSeconds: start * duration)
            engine.play()
        }
    }
}
