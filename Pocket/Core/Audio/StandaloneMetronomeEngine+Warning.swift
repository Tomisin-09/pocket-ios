import Foundation

/// The **tempo-change warning** (ADR 0131): what the run screen reads to know that the ramp is about
/// to step, and to what. Split out of `StandaloneMetronomeEngine` like `+Automator` and `+Driver` —
/// the core file sits at the 400-line ceiling, and this is one concern.
///
/// Everything here is derived, never stored: the arithmetic lives on the pure `CommandRamp` /
/// `MetronomeAutomator`, and this only decides *whether a warning applies right now* from state the
/// engine already tracks. Reading these while a run is playing invalidates the observing view on every
/// driver tick, so they belong in small dedicated views (the `BeatIndicator` pattern) rather than in a
/// screen's main `body`.
extension StandaloneMetronomeEngine {

    /// The change the ramp is approaching, **only once it is close enough to warn about** — `nil`
    /// whenever no warning should be showing.
    ///
    /// Four gates before the ramp is even asked. The setting is off; no ramp is driving; the transport
    /// isn't playing; or the run is still **counting in**, where the climb is deliberately held at its
    /// floor (ADR 0048) so any boundary the ramp reports is not actually approaching.
    var tempoWarning: PendingTempoChange? {
        guard AppSettings.tempoChangeWarning != .off,
              isRampActive, transport == .playing, !automatorCountingIn else { return nil }
        guard let change = activeRamp.pendingChange(elapsedBars: automatorBarsElapsed,
                                                    elapsedSeconds: automatorSecondsElapsed)
        else { return nil }
        return change.isArmed(bpm: bpm, beatsPerBar: timeSignature.beats) ? change : nil
    }

    /// The plateau the staircase **pre-lights** while a warning is showing — the one the ramp is about
    /// to move to. `nil` when there is no warning, or when the boundary being warned about is the end
    /// of the ramp (there is no next bar to light).
    var warningNextPlateau: Int? {
        guard let warning = tempoWarning, warning.to != nil,
              let ramp = trainingRamp, let current = currentRampPlateau else { return nil }
        let next = current + 1
        return next < ramp.plateaus.count ? next : nil
    }
}
