import Foundation

// MARK: - Tempo (tap-tempo / manual BPM, ADR 0024)

extension WaveformPracticeModel {

    /// "Set BPM" affordance — present the tap-tempo / manual-entry sheet (ADR 0024).
    /// Warm the Taptic Engine up front so the first tap-tempo buzz is instant.
    func setBPM() {
        settingBPM = true
        prepareHaptics(.light)
    }

    /// Commit a tempo from the BPM sheet. `bpm` is the full-precision value; we store it
    /// in `preciseBPM` (drives the beat grid without Int-rounding drift) and mirror the
    /// rounded value into `bpm` for the display readout. `downbeat` (the seconds a bar-1
    /// downbeat lands — "the 1") is set only when provided, so a BPM-only commit leaves
    /// any existing phase anchor untouched (ADR 0022/0026). Both are optional so the
    /// sheet can commit either independently; a fully-empty commit is a no-op.
    func commitTempo(bpm: Double?, downbeat: TimeInterval?) {
        if let bpm {
            song.preciseBPM = bpm
            song.bpm = Int(bpm.rounded())
        }
        if let downbeat {
            song.downbeatSeconds = downbeat
        }
        settingBPM = false
        if bpm != nil || downbeat != nil { haptic(.medium) }
    }

    // MARK: Set the 1 on the waveform (draggable downbeat handle, ADR 0024)

    /// Enter downbeat-placement: seed the handle at the existing downbeat, or the
    /// playhead if none. The waveform then drags it (snapping to peaks) and the
    /// downbeat toolbar confirms/cancels.
    func beginSetDownbeat() {
        let seed = song.downbeatSeconds.map { duration > 0 ? $0 / duration : 0 } ?? playheadFraction
        downbeatDraft = seed.clamped(to: 0...1)
        haptic(.medium)
    }

    /// Live drag of the downbeat handle — raw (tracks the finger), clamped on-song.
    /// Snapping happens on release so the handle doesn't fight the drag.
    func moveDownbeatDraft(to fraction: Double) {
        guard downbeatDraft != nil else { return }
        downbeatDraft = fraction.clamped(to: 0...1)
    }

    /// Drag released — snap the handle to the nearest conspicuous transient (snare/kick)
    /// among the displayed bars, within a screen-proportional window (ADR 0024). No peak
    /// in range ⇒ keep the raw drop.
    func endDownbeatDrag() {
        guard let draft = downbeatDraft else { return }
        let displayed = displayedBars
        let radius = 0.03 * (viewport.end - viewport.start)
        if let snapped = TempoPeaks.snap(toFraction: draft, bars: displayed.bars,
                                         coveredStart: displayed.start, coveredEnd: displayed.end,
                                         searchRadius: radius) {
            downbeatDraft = snapped
            haptic(.light)
        }
    }

    /// Confirm ✓ — commit the placed downbeat as the grid's phase anchor and exit.
    func confirmDownbeat() {
        guard let draft = downbeatDraft else { return }
        downbeatDraft = nil
        commitTempo(bpm: nil, downbeat: draft * duration)
    }

    /// Cancel ✗ — discard the placement, leaving any existing downbeat untouched.
    func cancelSetDownbeat() {
        downbeatDraft = nil
    }
}
