import Foundation
import SwiftData

// MARK: - The first-song walkthrough (ADR 0149, ADR 0220 D3)
//
// Three beats — Loop it, Slow it down, Keep it — run on the one visit `AppSettings+Walkthrough`
// arms, each completing on the real action the model already performs. On the starter track, beat 1
// is scripted: playback pauses on each of its two markers so the player's Loop taps land on them.
//
// **The playhead watcher is here, in the model, and never in a view body.** ADR 0153: a body that
// reads the playhead re-executes at display rate. The engine calls `walkthroughTick` once per frame
// through `onTick`, and nothing observable is written on a frame unless the script actually moved —
// otherwise the card, which reads `starterScript`, would redraw at 120 Hz for no change.

extension WaveformPracticeModel {

    /// Start the walkthrough if this is the visit that runs it. Called once the audio has loaded, so
    /// a song that cannot play spends nothing (see `AppSettings.takeArmedSongWalkthrough`).
    func beginWalkthroughIfArmed() {
        guard !isPreview, UITestRuntime.walkthroughIsOpen, walkthrough == nil,
              !audioLoadFailed, engine.duration > 0,
              AppSettings.takeArmedSongWalkthrough() else { return }
        let experience = (try? context.fetch(FetchDescriptor<Profile>()))?.first?.experience
        walkthrough = SongWalkthrough(entry: SongWalkthrough.entry(for: experience),
                                      ceremonyAlreadyShown: AppSettings.songWalkthroughCeremonySeen())
        if walkthrough?.isAccepted == true { startStarterTrackScript() }
    }

    /// *Show me* on the experienced player's offer (0149 §4).
    func acceptWalkthrough() {
        walkthrough?.accept()
        startStarterTrackScript()
        haptic(.light)
    }

    /// ✕ — permanent and silent (0149 §4). The ledger was already spent when the card appeared.
    /// Takes the hints with it: they belong to the walkthrough's session, not beside it (D4).
    func dismissWalkthrough() {
        walkthrough = nil
        starterHints = nil
        stopStarterTrackScript()
    }

    /// Close the ceremony. A beat still outstanding (the span was kept before it was slowed) comes
    /// back, and so does a hint waiting behind it; otherwise the walkthrough is over.
    func dismissWalkthroughCeremony() {
        walkthrough?.dismissCeremony()
        endWalkthroughIfDone()
    }

    /// Over when no beat is outstanding and no hint is showing — the backing-track hint arrives
    /// after the last beat, so the beats alone cannot say (ADR 0220 D4).
    func endWalkthroughIfDone() {
        guard walkthrough?.phase == .finished, starterHints?.showing == nil else { return }
        dismissWalkthrough()
    }

    /// Report something the player did. Every hook calls this; it no-ops on any visit not running the
    /// walkthrough, which is almost all of them.
    func recordWalkthrough(_ event: SongWalkthrough.Event) {
        guard var next = walkthrough else { return }
        let marksTheMoment = next.record(event)
        // Written only on a change: `.speedChanged` arrives on every frame of a slider drag.
        if next != walkthrough { walkthrough = next }
        if marksTheMoment {
            AppSettings.recordSongWalkthroughCeremonySeen()
            haptic(.success)
        }
        endWalkthroughIfDone()
    }

    /// Whether the Loop button carries the hint: the script is holding on a marker (D3).
    var walkthroughHintsLoop: Bool { starterScript?.hintsLoop == true }

    // MARK: Hooks

    /// `abSpan`'s observer. A fresh span closing is beat 1; a saved loop lifted in for a range edit
    /// is not a new loop and does not count.
    func walkthroughSpanDidChange(from old: ABSpan) {
        guard walkthrough != nil else { return }
        advanceScript { $0.spanChanged(scriptSpan) }
        guard !old.isSet, abSpan.isSet, abEditingLoop == nil else { return }
        // The span loops the moment it closes, so this is also "beat 1's loop is playing" — the
        // click hint's cue (ADR 0220 D4). Offered before the beat is recorded, so the card that
        // moves on to *Slow it down* arrives with it rather than redrawing twice.
        walkthroughLoopStarted()
        recordWalkthrough(.spanClosed)
    }

    /// One display frame of playback (`PracticeAudioEngine.onTick`).
    func walkthroughTick(_ time: TimeInterval) {
        var stop: TimeInterval?
        advanceScript { stop = $0.tick(from: lastWalkthroughTick, to: time, span: scriptSpan) }
        guard let stop else {
            lastWalkthroughTick = time
            return
        }
        // Seek back **onto** the marker rather than pausing wherever this frame overshot it (D3): at
        // 120 Hz that is up to ~16 ms late, the very lateness the pause exists to remove. The next
        // Loop tap reads the playhead, so A — and then B — land exactly on the bar line.
        engine.pause()
        engine.seek(toSeconds: stop)
        lastWalkthroughTick = stop
        haptic(.light)
    }

    // MARK: The script (starter track only — D6)

    private func startStarterTrackScript() {
        guard song.isStarterTrack, starterScript == nil else { return }
        let script = StarterTrackScript()
        starterScript = script
        starterHints = StarterTrackHints()     // D4 rides with the script: starter track only (D6)
        // D3 step 1: two bars early, so the section is heard arriving. Not while a saved loop is
        // armed — a seek outside its region would land somewhere the loop never plays.
        if activeLoopID == nil { engine.seek(toSeconds: script.leadIn) }
        lastWalkthroughTick = engine.currentTime
        advanceScript { $0.spanChanged(scriptSpan) }
        engine.onTick = { [weak self] time in self?.walkthroughTick(time) }
    }

    private func stopStarterTrackScript() {
        starterScript = nil
        engine.onTick = nil
    }

    /// Mutate the script, writing it back only if it changed, and retire it once the span has closed.
    private func advanceScript(_ change: (inout StarterTrackScript) -> Void) {
        guard var script = starterScript else { return }
        change(&script)
        if script.stage == .finished {
            stopStarterTrackScript()
        } else if script != starterScript {
            starterScript = script
        }
    }

    /// The A/B span in the script's terms: song seconds rather than fractions.
    private var scriptSpan: StarterTrackScript.Span {
        switch abSpan {
        case .idle: return .idle
        case .armed(let pointA): return .armed(pointA * duration)
        case .set: return .set
        }
    }
}
