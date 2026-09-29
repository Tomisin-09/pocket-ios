import Foundation

extension SongMapInput {
    /// Read a song's loops, markers and grid into the map's input (ADR 0232).
    ///
    /// **Bars only when the grid is there and shown** (D5): a tempo and a 1, and the song's own
    /// gridlines switch on (ADR 0051). A player who hid the grid on the waveform because it's wrong
    /// doesn't want bars drawn from it here either.
    init(song: Song) {
        let duration = song.duration
        self.init(duration: duration,
                  grid: Self.grid(for: song),
                  markers: song.markers.map {
                      MarkerInput(uid: $0.uid, seconds: $0.seconds, label: $0.label,
                                  startsSection: $0.startsSection, sameAsUID: $0.sameAsUID)
                  },
                  loops: song.loops.map { loop in
                      LoopInput(uid: loop.uid, name: loop.name.isEmpty ? "Loop" : loop.name,
                                start: loop.start * duration, end: loop.end * duration,
                                type: loop.loopType, piece: loop.transcription,
                                handTagged: loop.journal.contains { $0.kind == .transcribed },
                                repeatsToSectionEnd: loop.repeatsToSectionEnd)
                  })
    }

    /// The song's downbeats, or `nil` when it has no grid or hides it.
    static func grid(for song: Song) -> Grid? {
        guard song.showsGridlines, let bpm = song.tempoBPM, bpm > 0, song.duration > 0 else { return nil }
        let anchors = song.downbeatAnchors
        guard !anchors.isEmpty else { return nil }
        let downbeats = BeatGrid.beats(bpm: bpm, duration: song.duration, anchors: anchors,
                                       beatsPerBar: song.beatsPerBar)
            .filter(\.isDownbeat)
            .map { $0.fraction * song.duration }
        guard !downbeats.isEmpty else { return nil }
        return Grid(downbeats: downbeats, barSeconds: 60 / bpm * Double(max(1, song.beatsPerBar)))
    }

    /// Whether the song has a grid to draw bars from, shown or not: what decides if the **Bars** chip is
    /// offered at all.
    static func hasGrid(_ song: Song) -> Bool {
        song.tempoBPM != nil && !song.downbeatAnchors.isEmpty
    }
}
