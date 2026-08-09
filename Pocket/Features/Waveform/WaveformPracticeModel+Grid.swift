import Foundation

// MARK: - Beat grid (ADR 0022) and the in-song click (ADR 0026)

extension WaveformPracticeModel {

    /// The beat grid (ADR 0022): beats + bar-start downbeats as song fractions.
    /// Empty unless the song has **both** a tempo (`bpm`) and a **downbeat anchor**
    /// (`downbeatSeconds`) — BPM fixes the interval, the anchor fixes the phase, and we
    /// don't guess the phase. Drawn faintly on the waveform and fed into the snap
    /// candidates (`snapCandidates`). Bar lines follow the song's time signature
    /// (`beatsPerBar`, ADR 0051; default 4/4).
    ///
    /// **Memoised.** `BeatGrid.beats` allocates a beat for every beat in the *whole song* —
    /// ~480 of them for four minutes at 120 BPM — and this is read by the waveform, the
    /// gridlines toggle (`gridAvailable`), the click gate (`canUseMetronome`) and the snap
    /// candidates. Recomputing all of that on every read put an allocation storm behind a value
    /// that changes only when the tempo, the 1, the time signature or the song's length does.
    /// Keyed on exactly those four rather than rebuilt by hand at each mutation site, because
    /// the song's tempo fields are also written from outside this model (`SongEditSheet`), and
    /// a cache that can be missed is worse than no cache at all.
    var beatGrid: [BeatGrid.Beat] {
        let key = GridKey(bpm: song.tempoBPM, anchors: song.downbeatAnchors,
                          beatsPerBar: song.beatsPerBar, duration: duration)
        if let cached = gridCache, cached.key == key { return cached.beats }
        guard let bpm = key.bpm, !key.anchors.isEmpty, key.duration > 0 else {
            gridCache = (key, [])
            return []
        }
        let beats = BeatGrid.beats(bpm: bpm, duration: key.duration, anchors: key.anchors,
                                   beatsPerBar: key.beatsPerBar)
        gridCache = (key, beats)
        return beats
    }

    /// Everything `beatGrid` is derived from. Equal key ⇒ the cached array is still correct.
    /// `anchors` rather than a single downbeat since ADR 0154 — adding or removing a correction
    /// has to miss the cache, or the grid would silently keep the phase you just corrected.
    struct GridKey: Equatable {
        let bpm: Double?
        let anchors: [TimeInterval]
        let beatsPerBar: Int
        let duration: TimeInterval
    }

    /// The song's phase anchors as song fractions, for drawing (ADR 0154). Seconds are the
    /// stored form; the waveform works in fractions.
    var downbeatAnchorFractions: [Double] {
        guard duration > 0 else { return [] }
        return song.downbeatAnchors.map { ($0 / duration).clamped(to: 0...1) }
    }

    /// A grid exists to show/hide only once tempo + downbeat are set — gates the gridlines
    /// toggle's visibility (ADR 0051), the same condition that makes `beatGrid` non-empty.
    var gridAvailable: Bool { !beatGrid.isEmpty }

    /// Tempo set, but no **1** placed — so `beatGrid` is empty and there are no gridlines, no bar
    /// lines and no beat snapping. It's the state a BPM-only commit leaves behind (`commitTempo`
    /// deliberately won't guess the phase, ADR 0022), and on device it reads as "I set the BPM, where's
    /// my grid?" because *nothing* appears in the Grid toggle's place. Drives a **Set the 1** prompt
    /// there instead of silence.
    var needsDownbeat: Bool { song.tempoBPM != nil && song.downbeatSeconds == nil }

    /// Toggle this song's gridlines (ADR 0051). Mutating the `@Model` persists the per-song
    /// preference; the grid still feeds snap candidates when hidden.
    /// No haptic here: the control is a `ToggleChip`, which fires its own. Two would stack into one
    /// heavier-feeling tap that reads as a different gesture.
    func toggleGridlines() {
        song.showsGridlines.toggle()
    }

    // MARK: - Metronome (ADR 0026)

    /// A click can run only when there's a grid — both a tempo and a downbeat anchor.
    /// Drives the transport toggle's enabled state (the button greys out without one).
    var canUseMetronome: Bool { !beatGrid.isEmpty }

    /// Toggle the in-song click. Pushes the current grid to the engine and flips the
    /// click on/off; the engine schedules against the live (rate-following) playhead.
    func toggleMetronome() {
        guard canUseMetronome || metronomeOn else { return }
        metronomeOn.toggle()
        if metronomeOn { pushMetronomeGrid() }
        engine.setMetronome(enabled: metronomeOn)
    }

    /// Hand the engine the beat grid in *source* seconds (fractions × duration). Called
    /// when the click turns on and whenever the grid changes (tempo/downbeat edits).
    func pushMetronomeGrid() {
        let beats = beatGrid.map { (time: $0.fraction * duration, isDownbeat: $0.isDownbeat) }
        engine.setMetronomeBeats(beats)
    }
}
