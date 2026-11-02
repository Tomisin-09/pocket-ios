import Foundation

// MARK: - The click inside the tempo sheet (ADR 0283)

extension WaveformPracticeModel {

    /// The grid Done would leave with the sheet's values, by `commitTempo`'s own rules: a tempo
    /// given replaces the beat map (ADR 0281 D4), a 1 given replaces the song's 1 and keeps its
    /// corrections (ADR 0154), and the bar is the one chosen. `nil` is "leave it", as it is there.
    /// What the sheet's click plays is then what Done keeps.
    func gridIfCommitted(bpm: Double?, downbeat: TimeInterval?, beatsPerBar: Int) -> [BeatGrid.Beat] {
        let anchors = downbeat.map { ([$0] + song.extraDownbeatSeconds).sorted() } ?? song.downbeatAnchors
        return BeatGrid.beats(bpm: bpm ?? song.tempoBPM, map: bpm == nil ? song.beatTimes : [],
                              duration: duration, anchors: anchors, beatsPerBar: beatsPerBar)
    }

    /// The sheet's click, on or off, playing values not yet saved. Only the engine's click changes:
    /// `metronomeOn` stays the song's until Done (`endClickPreview`).
    func previewClick(_ values: TempoClickHooks.Values) {
        let grid = gridIfCommitted(bpm: values.bpm, downbeat: values.downbeat, beatsPerBar: values.beatsPerBar)
        engine.setMetronomeBeats(grid.map { (time: $0.fraction * duration, isDownbeat: $0.isDownbeat) })
        engine.setMetronome(enabled: values.isOn)
    }

    /// The sheet has closed, so the click is the song's again. `keepOn` is the sheet's switch when
    /// Done was tapped; `nil` is any other way out (Cancel, a swipe down, Set the 1 on the waveform),
    /// which puts back the click as it was. Either way it plays the song's grid as it now stands.
    func endClickPreview(keepOn: Bool?) {
        if let keepOn {
            let wasOn = metronomeOn
            metronomeOn = keepOn && canUseMetronome
            if metronomeOn, !wasOn { walkthroughClickTurnedOn() }   // the click hint is taken (ADR 0220 D4)
        }
        pushMetronomeGrid()
        engine.setMetronome(enabled: metronomeOn)
    }
}
