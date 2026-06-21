import SwiftUI

/// Per-loop speed-ramp automator (ADR 0013), split out of `WaveformPracticeModel` so
/// the core model stays under the file-length budget. These hooks are driven by the
/// engine's loop wraps and the automator sheet; they touch only the model's transient
/// session state (`speed`, the active loop), never persisted song data.
extension WaveformPracticeModel {

    /// Apply the active loop's speed ramp at a new loop iteration (driven by the engine's
    /// `loopIteration`). No-op unless that loop's automator is enabled and it's playing.
    /// Sets `speed`, which the view feeds to the engine via its existing `onChange`. Once
    /// the ramp has played its last automated pass (`totalLoops`), playback **stops** and
    /// rewinds to the loop start so the ramp can be replayed from the top (ADR 0013).
    func automatorAdvance(toLoopIteration iteration: Int) {
        guard let loop = activeLoop, loop.automatorEnabled, engine.isPlaying else { return }
        let config = loop.automator
        if iteration >= config.totalLoops {
            engine.pause()
            engine.seek(toSeconds: loop.startSeconds)   // rewind (resets the wrap counter) so a replay starts fresh
            return
        }
        let target = config.speed(atLoopIteration: iteration)
        if abs(target - speed) > 0.0001 { speed = target }
    }

    /// "Set ramp" on the automator sheet: arm the loop's ramp, make it the active loop,
    /// and start playing it from the top at the ramp's start speed (ADR 0013).
    func startAutomator(for loop: Loop) {
        speed = loop.automator.speed(atLoopIteration: 0)   // begin at the ramp start
        activeLoopID = loop.uid
        applyActiveLoopToEngine()
        engine.seek(toSeconds: loop.startSeconds)
        engine.play()
    }

    /// "Turn off ramp" on the automator sheet: the sheet has already written
    /// `enabled = false`, so the next loop wrap's `automatorAdvance` simply no-ops and the
    /// speed stops changing. Nothing else to do — kept as a named hook for the view.
    func turnOffAutomator(for loop: Loop) {}

    /// The user grabbed the speed slider — hand control back by disabling the active
    /// loop's ramp, so it stops fighting the manual setting.
    func userAdjustedSpeed() {
        activeLoop?.automatorEnabled = false
    }
}
