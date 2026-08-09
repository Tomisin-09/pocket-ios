import Foundation

// MARK: - Tempo (tap-tempo / manual BPM, ADR 0024)

extension WaveformPracticeModel {

    /// "Set BPM" affordance — present the tap-tempo / manual-entry sheet (ADR 0024).
    /// Warm the Taptic Engine up front so the first tap-tempo buzz is instant.
    func setBPM() {
        settingBPM = true
        prepareHaptics(.light)
    }

    /// Estimate the song's tempo **and downbeat phase** on-device from its audio — rung 2
    /// of ADR 0004's fallback chain. Decodes an onset envelope off the main actor, then
    /// autocorrelates it for the tempo and comb-filters it for the phase (`TempoEstimator`).
    /// Returns `nil` when there's no source file (the demo sample) or the material is too
    /// flat/ambient for a confident read. The estimate is *not* committed here — the BPM
    /// sheet prefills it, flagged as estimated, for the user to confirm or correct (ADR
    /// 0004: estimates aren't truth).
    func estimateTempoFromAudio() async -> TempoEstimator.Estimate? {
        guard let url = sourceURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let extracted = try? WaveformExtractor.extractOnsetEnvelope(from: url) else { return nil }
            return TempoEstimator.estimate(onsets: extracted.onsets,
                                           framesPerSecond: extracted.framesPerSecond)
        }.value
    }

    /// Commit a tempo from the BPM sheet. `bpm` is the full-precision value; we store it
    /// in `preciseBPM` (drives the beat grid without Int-rounding drift) and mirror the
    /// rounded value into `bpm` for the display readout. `downbeat` (the seconds a bar-1
    /// downbeat lands — "the 1") is set only when provided, so a BPM-only commit leaves
    /// any existing phase anchor untouched (ADR 0022/0026). Both are optional so the
    /// sheet can commit either independently; a fully-empty commit is a no-op.
    func commitTempo(bpm: Double?, downbeat: TimeInterval?,
                     beatsPerBar: Int? = nil, noteValue: Int? = nil) {
        if let bpm {
            song.preciseBPM = bpm
            song.bpm = Int(bpm.rounded())
        }
        if let downbeat {
            song.downbeatSeconds = downbeat
        }
        // Time signature (ADR 0051) — groups the beat grid into bars; default 4/4.
        if let beatsPerBar { song.beatsPerBar = max(1, beatsPerBar) }
        if let noteValue { song.noteValue = max(1, noteValue) }
        settingBPM = false
        if bpm != nil || downbeat != nil || beatsPerBar != nil { haptic(.medium) }
        if metronomeOn { pushMetronomeGrid() }   // grid changed — keep the click in sync (ADR 0026)
    }

    // MARK: Set the 1 on the waveform (draggable downbeat handle, ADR 0024)

    /// Enter downbeat-placement: seed the handle at the existing downbeat, or the
    /// playhead if none. The waveform then drags it (snapping to peaks), the transport
    /// stays live so the user can **play along and tap the 1**, and the downbeat toolbar
    /// confirms/cancels. `resumeSheet` re-presents the BPM sheet on exit (set when this
    /// was launched from "Set the 1 on the waveform").
    func beginSetDownbeat(resumeSheet: Bool = false) {
        resumeBPMSheetAfterDownbeat = resumeSheet
        let seed = song.downbeatSeconds.map { duration > 0 ? $0 / duration : 0 } ?? playheadFraction
        downbeatDraft = seed.clamped(to: 0...1)
        haptic(.medium)
    }

    /// Play-along capture: drop the 1 at the **live playhead** the moment the user feels
    /// the downbeat, and pause so they can confirm or nudge it. A tap is a little late, so
    /// the position snaps to the nearest transient within a short (~120 ms) window —
    /// enough to land on the actual kick/snare without the big jumps a zoom-proportional
    /// radius would cause at full zoom. No peak that close ⇒ keep the raw playhead.
    func captureDownbeatAtPlayhead() {
        guard downbeatDraft != nil, duration > 0 else { return }
        engine.pause()
        let captured = playheadFraction
        let displayed = displayedBars
        let radius = 0.12 / duration
        downbeatDraft = TempoPeaks.snap(toFraction: captured, bars: displayed.bars,
                                        coveredStart: displayed.start, coveredEnd: displayed.end,
                                        searchRadius: radius) ?? captured
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

    /// Confirm ✓ — land the placed 1 and exit, returning to the BPM sheet if we came from it.
    ///
    /// Which of the two things this means depends on whether the song already has a 1, and the
    /// distinction is the whole of ADR 0154. With no anchor yet, this *is* the anchor. With one
    /// already placed, the player is telling us where the 1 has drifted to further into the
    /// song — so it lands as a **correction from here**, leaving the original where it is.
    /// Replacing the original is the rarer intent and has its own control (`moveDownbeat`).
    func confirmDownbeat() {
        guard let draft = downbeatDraft else { return }
        let seconds = draft * duration
        downbeatDraft = nil
        if song.downbeatSeconds == nil {
            commitTempo(bpm: nil, downbeat: seconds)
        } else {
            addDownbeatCorrection(at: seconds)
        }
        resumeBPMSheetIfNeeded()
    }

    /// "Move the 1 instead" — replace the primary anchor rather than correcting from the drop.
    /// For the case where the original 1 was simply in the wrong place; corrections are left
    /// alone, since they're anchored to their own sections and are still where they should be.
    func moveDownbeat() {
        guard let draft = downbeatDraft else { return }
        downbeatDraft = nil
        commitTempo(bpm: nil, downbeat: draft * duration)
        resumeBPMSheetIfNeeded()
    }

    /// Record a correction at `seconds` (ADR 0154). Dropping one within half a beat of an anchor
    /// that already exists is a **nudge to that anchor**, not a new one: two anchors that close
    /// together can't both be a 1, `BeatGrid` would discard the later one anyway, and storing it
    /// would leave a correction in the song that provably does nothing.
    func addDownbeatCorrection(at seconds: TimeInterval) {
        guard let bpm = song.tempoBPM, bpm > 0 else {
            song.downbeatSeconds = seconds
            return
        }
        let minGap = (60.0 / bpm) / 2
        if let primary = song.downbeatSeconds, abs(seconds - primary) < minGap {
            song.downbeatSeconds = seconds
        } else if let existing = song.extraDownbeatSeconds.firstIndex(where: {
            abs($0 - seconds) < minGap
        }) {
            song.extraDownbeatSeconds[existing] = seconds
        } else {
            song.extraDownbeatSeconds = (song.extraDownbeatSeconds + [seconds]).sorted()
        }
        haptic(.medium)
        if metronomeOn { pushMetronomeGrid() }   // grid changed — keep the click in sync (ADR 0026)
    }

    /// Drop every correction, returning the song to a single-anchor grid. Undoable, which is what
    /// makes one clear-all button an honest removal path: corrections are cheap to re-place, and
    /// getting them all back is one tap if this wasn't what you meant.
    func clearDownbeatCorrections() {
        let removed = song.extraDownbeatSeconds
        guard !removed.isEmpty else { return }
        song.extraDownbeatSeconds = []
        if metronomeOn { pushMetronomeGrid() }
        haptic(.medium)
        presentUndo("Cleared \(removed.count) correction\(removed.count == 1 ? "" : "s")") { [weak self] in
            guard let self else { return }
            self.song.extraDownbeatSeconds = removed
            if self.metronomeOn { self.pushMetronomeGrid() }
        }
    }

    /// Cancel ✗ — discard the placement, leaving any existing downbeat untouched, and
    /// return to the BPM sheet if we came from it.
    func cancelSetDownbeat() {
        downbeatDraft = nil
        resumeBPMSheetIfNeeded()
    }

    /// Re-present the BPM sheet after a downbeat placement that was launched from it.
    private func resumeBPMSheetIfNeeded() {
        guard resumeBPMSheetAfterDownbeat else { return }
        resumeBPMSheetAfterDownbeat = false
        settingBPM = true
    }
}
