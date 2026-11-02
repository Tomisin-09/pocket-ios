import Foundation

// MARK: - The beat map: tap through a song (ADR 0281)

extension WaveformPracticeModel {

    /// The open song's onset envelope (B1), decoded off the main actor, for snapping taps onto the
    /// hits they were aimed at. `nil` when there's no file to read or it decodes to nothing; the
    /// taps are then kept as tapped.
    func onsetEnvelope() async -> BeatMap.Onsets? {
        guard let url = sourceURL else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let extracted = try? WaveformExtractor.extractOnsetEnvelope(from: url) else { return nil }
            return BeatMap.Onsets(values: extracted.onsets, framesPerSecond: extracted.framesPerSecond)
        }.value
    }

    /// Play the whole song from the top, for tapping through it. An armed loop or an A/B span would
    /// keep playback inside one stretch, so both are let go first, the way the exit-loop chip does.
    /// The speed is kept: taps read the playhead in song time, so a slowed song still maps true.
    func playWholeSongFromStart() {
        abSpan = .idle
        abEditingLoop = nil
        if activeLoopID != nil { activeLoopID = nil }
        applyActiveLoopToEngine()
        engine.seek(toSeconds: 0)
        engine.play()
    }

    /// Store a tap-through as the song's beat map (ADR 0281). Each tap is snapped onto a clear hit
    /// near it (`BeatMap.snapped`), then cleaned into a map (`BeatMap.fromTaps`). Returns `false`,
    /// changing nothing, when the taps don't make a map.
    ///
    /// The tempo becomes the map's median, so the readout and everything that reads one tempo keep
    /// working. The 1 stays where the player put it, moved onto the beat nearest it; a song with no
    /// 1 yet takes the first tap as its 1, because the screen asks the player to start on one.
    /// Undoable, since a tap-through replaces a tempo and a 1 that may have taken care to set.
    @discardableResult
    func commitBeatMap(taps: [TimeInterval], onsets: BeatMap.Onsets?) -> Bool {
        let placed = onsets.map { BeatMap.snapped(taps, to: $0) } ?? taps
        let map = BeatMap.fromTaps(placed)
        guard BeatMap.isMap(map), let median = BeatMap.medianBPM(map) else { return false }
        let before = TempoSnapshot(song)
        song.beatTimes = map
        song.preciseBPM = median
        song.bpm = Int(median.rounded())
        if let one = song.downbeatSeconds,
           let beats = BeatMap.extended(map, through: max(duration, map.last ?? 0), limit: BeatGrid.maxBeats),
           let index = BeatMap.nearestIndex(to: one, in: beats) {
            song.downbeatSeconds = beats[index]
        } else {
            song.downbeatSeconds = map.first
        }
        settingBPM = false
        haptic(.medium)
        if metronomeOn { pushMetronomeGrid() }
        presentUndo("Using \(map.count) beats") { [weak self] in self?.restore(before) }
        return true
    }

    /// Go back to one tempo: the map is dropped and `preciseBPM`, its median, stays as the tempo.
    /// From the tempo sheet's *Use one tempo* control. Undoable for the same reason as the commit.
    func clearBeatMap() {
        guard !song.beatTimes.isEmpty else { return }
        let before = TempoSnapshot(song)
        song.beatTimes = []
        if metronomeOn { pushMetronomeGrid() }
        haptic(.medium)
        presentUndo("Back to one tempo") { [weak self] in self?.restore(before) }
    }

    /// Put a snapshot back and keep the click in step with it.
    func restore(_ snapshot: TempoSnapshot) {
        snapshot.apply(to: song)
        if metronomeOn { pushMetronomeGrid() }
    }
}

/// The song's tempo fields as they were before a change that replaces them, for its undo.
struct TempoSnapshot {
    let beatTimes: [TimeInterval]
    let preciseBPM: Double?
    let bpm: Int?
    let downbeatSeconds: TimeInterval?

    init(_ song: Song) {
        beatTimes = song.beatTimes
        preciseBPM = song.preciseBPM
        bpm = song.bpm
        downbeatSeconds = song.downbeatSeconds
    }

    func apply(to song: Song) {
        song.beatTimes = beatTimes
        song.preciseBPM = preciseBPM
        song.bpm = bpm
        song.downbeatSeconds = downbeatSeconds
    }
}
