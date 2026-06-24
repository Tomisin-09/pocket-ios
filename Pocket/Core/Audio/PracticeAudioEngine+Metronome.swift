import AVFoundation

// The metronome's click scheduling (ADR 0026), split out of `PracticeAudioEngine.swift`
// for file length. The on/off toggle (`setMetronome`) stays with the engine; this file
// holds the grid update and the per-tick arming / flushing / scheduling. The engine's
// click state (`clickVoice`, `metronomeBeats`, watermark, …) is engine-internal so this
// extension — in the same module — can drive it.
extension PracticeAudioEngine {

    /// Update the song's beat grid (source seconds + downbeat flags), e.g. when the BPM
    /// or downbeat changes. Drops any stale schedule.
    func setMetronomeBeats(_ beats: [(time: TimeInterval, isDownbeat: Bool)]) {
        metronomeBeats = beats
        flushMetronome()
    }

    /// Begin (or resume) the click voice for the current playback and reset the dedup
    /// watermark so the next tick refills from the live playhead.
    func armMetronome() {
        guard metronomeOn, isPlaying else { return }
        clickVoice.start()
        clickWatermark = -.infinity
        metronomeLoopIteration = loopIteration
    }

    /// Cancel queued clicks and reset the watermark; re-arm if still playing. Called on
    /// any timing discontinuity (seek / rate / loop change / grid change) so a click is
    /// never heard at a stale time.
    func flushMetronome() {
        clickVoice.stopAll()
        clickWatermark = -.infinity
        if metronomeOn, isPlaying {
            clickVoice.start()
            metronomeLoopIteration = loopIteration
        }
    }

    /// Schedule the clicks now due within the lookahead horizon (one per beat, deduped
    /// by the watermark). Follows the playback rate, so the click tracks a slowed or
    /// sped track. During an active loop, a new pass resets the watermark so the
    /// region's beats re-fire, and beats past the loop end are skipped (playback wraps
    /// before reaching them).
    func refreshMetronome() {
        guard metronomeOn, isPlaying, !metronomeBeats.isEmpty else { return }
        if loopIteration != metronomeLoopIteration {
            metronomeLoopIteration = loopIteration
            clickWatermark = -.infinity            // new loop pass ⇒ re-fire the region
        }
        let cutoff = loopRegion?.end ?? .infinity
        let clicks = MetronomeSchedule.upcoming(beats: metronomeBeats,
                                                currentSourceTime: currentTime,
                                                rate: Double(timePitch.rate),
                                                horizon: metronomeHorizon)
        for click in clicks where click.time > clickWatermark && click.time < cutoff {
            clickVoice.schedule(delay: click.delay, accented: click.isDownbeat)
            clickWatermark = click.time
        }
    }
}
