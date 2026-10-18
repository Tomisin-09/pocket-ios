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
    ///
    /// The finish also **disarms** the ramp (ADR 0260 D3). The automator sheet is still up while the
    /// ramp plays, and reads "started here, no longer armed" as *Done*, offering *Run again*. It also
    /// makes the next press of play the player's own: it no longer restarts a ramp that has finished.
    func automatorAdvance(toLoopIteration iteration: Int) {
        guard let loop = activeLoop, loop.automatorEnabled, engine.isPlaying else { return }
        let config = loop.automator
        if config.progress(atLoopIteration: iteration).isFinished {
            loop.automatorEnabled = false
            engine.pause()
            engine.seek(toSeconds: loop.startSeconds)   // rewind (resets the wrap counter) so a replay starts fresh
            return
        }
        let target = config.speed(atLoopIteration: iteration)
        if abs(target - speed) > 0.0001 { speed = target }
    }

    /// "Set ramp" (and "Run again") on the automator sheet: arm the loop's ramp, make it the active
    /// loop, and start playing it from the top at the ramp's start speed (ADR 0013).
    func startAutomator(for loop: Loop) {
        speed = loop.automator.speed(atLoopIteration: 0)   // begin at the ramp start
        activeLoopID = loop.uid
        applyActiveLoopToEngine()
        engine.seek(toSeconds: loop.startSeconds)
        engine.play()
    }

    /// "Stop ramp" on the automator sheet, and leaving the sheet mid-run (ADR 0260 D3): disarm, so the
    /// next wrap's `automatorAdvance` no-ops, and **pause** — what the ramp's own finish already does.
    /// The speed stays where the ramp had reached.
    func stopAutomator(for loop: Loop) {
        loop.automatorEnabled = false
        engine.pause()
    }

    /// The user grabbed the speed slider — hand control back by disabling the active
    /// loop's ramp, so it stops fighting the manual setting.
    func userAdjustedSpeed() {
        activeLoop?.automatorEnabled = false
        // From here the speed is the player's until the app sets it itself — this is what lets
        // `speed`'s observer tell a deliberate change from an arming-speed write.
        speedIsUserDriven = true
    }
}
