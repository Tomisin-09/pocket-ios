import SwiftUI

// MARK: - Transport playback controls (ADR 0030 · 0124 · 0192)
//
// The rewind · pause · forward cluster in the transport bar. The outer glyphs mean **one thing in
// both states** (ADR 0192): move ±N seconds through whatever is playing. What the armed loop
// changes is the *scope*, not the gesture — a skip is clamped to the loop region, because an armed
// loop plays as a pre-rendered crossfaded buffer (ADR 0008) and a skip past its end would be a
// disarm rather than a seek.
//
// That reunifies the two grammars this file used to carry. ADR 0030's restart / previous-loop /
// next-loop steps are withdrawn: loop-to-loop navigation lives in the Loops panel, where loops
// live (`activate(_:)` in `+Actions.swift`), and restarting is a tap on the loop's start — the same
// argument ADR 0124 already made for the idle state.
//
// The skip maths stay pure in `TransportSkip`; this file is the engine wiring.

extension WaveformPracticeModel {

    /// The active loop's identity colour for the transport strip, or `nil` when no
    /// loop is active (the strip is absent in that layout).
    var activeLoopColor: Color? {
        activeLoop.map { LoopColor.color(for: $0, among: loops) }
    }

    // MARK: Timed skip + whole-song repeat (ADR 0124, ADR 0192)

    /// What a skip is clamped to right now. Read off the **engine's** armed region rather than
    /// `activeLoop`, so an unsaved A/B span (ADR 0041) — which is just as much "what is playing" —
    /// scopes the buttons the same way a saved loop does.
    var transportSkipBounds: ClosedRange<TimeInterval> {
        TransportSkip.bounds(loopRegion: engine.loopRegion, duration: duration)
    }

    /// Skip `delta` seconds from the playhead (negative rewinds), clamped to whatever is armed.
    /// Seek only — the play/pause state is left alone, so skipping while paused stays paused.
    func transportSkip(bySeconds delta: TimeInterval) {
        engine.seek(toSeconds: TransportSkip.target(from: engine.currentTime, by: delta,
                                                    within: transportSkipBounds))
        haptic(.light)
    }

    /// Whether whole-song repeat is offered right now. An armed loop is *already* repeating its own
    /// region — the engine never reaches the file's end — so the control reads disabled rather than
    /// silently doing nothing.
    var canRepeatSong: Bool { activeLoop == nil }

    /// Toggle whole-song repeat (ADR 0124).
    func toggleRepeatsSong() {
        guard canRepeatSong else { return }
        repeatsSong.toggle()
        haptic(.light)
    }

    /// The engine hit the file's natural end. With repeat on, wrap to the top and keep playing;
    /// otherwise leave the engine's own stop-and-rewind alone. Straight-through playback only —
    /// this never fires while a loop is armed.
    func handleReachedEnd() {
        guard repeatsSong else { return }
        engine.seek(toSeconds: 0)
        engine.play()
    }

    // MARK: Waveform-touch bracket (swipe-back guard)

    /// A finger landed on the waveform — arm the swipe-back guard (ADR 0030).
    func beginWaveformTouch() { isScrubbing = true }

    /// The waveform touch ended — release the guard.
    func endWaveformTouch() { isScrubbing = false }
}
