import Foundation

extension Song {
    /// In-memory demo song — the generated arpeggio (`SampleToneGenerator`) is its
    /// audio. Seeded into the store on first launch and used by previews.
    /// `bookmark == nil` flags it as the sample (no real file behind it).
    ///
    /// **Every field here is fabricated on purpose, and names nobody real.** This is the
    /// only invented record that *ships* — `LibraryView.addDemo` inserts it behind
    /// **Try the demo**, so whatever it claims to be, a released build claims on our
    /// behalf. It used to be "Little Wing" by Jimi Hendrix, album "Axis: Bold as Love",
    /// in a collection called "Hendrix study". The audio was always a generated arpeggio,
    /// so nothing was ever reproduced — but a real artist's name and album carried as
    /// commercial demo content is a trademark and publicity question rather than a
    /// copyright one, and it is not one worth having. Keep this attributed to us.
    ///
    /// The loop and marker names are deliberately generic (`Verse riff`, `Chorus bend`,
    /// `Intro turnaround`, `Tricky bend`): the user manual navigates by them in roughly
    /// twenty figures, so they are the expensive half to rename and the half that never
    /// needed renaming.
    static func sample() -> Song {
        let duration: TimeInterval = 30
        let song = Song(title: "Slow Bend", artist: "Jack Trader",
                        album: "Demos", year: 2024, key: MusicalKey.gMinor.rawValue,
                        bpm: 76,
                        collections: ["Slow blues", "Bends & vibrato"],
                        comment: "Let the bends sit just under pitch on the way up.",
                        duration: duration, amplitudes: demoAmplitudes(count: 120),
                        ref: SongRef(id: "sample", source: .localFile, bookmark: nil))
        let loops = [
            Loop(name: "Verse riff", start: 0.29, end: 0.47, speed: 0.75, repeats: 4),
            Loop(name: "Chorus bend", start: 0.62, end: 0.71, speed: 1.0, repeats: 2)
        ]
        loops[0].mastery = 4   // rolls up to a derived song mastery of 3 (ADR 0036)
        loops[1].mastery = 2
        let markers = [
            Marker(seconds: 8, label: "Intro turnaround"),
            Marker(seconds: 22, label: "Tricky bend")
        ]
        song.loops = loops
        song.markers = markers
        for loop in loops where loop.song == nil { loop.song = song }
        for marker in markers where marker.song == nil { marker.song = song }
        return song
    }

    /// Deterministic, organic-looking amplitudes so the waveform reads as music
    /// before a real file's waveform is extracted (and for previews/screenshots).
    static func demoAmplitudes(count: Int) -> [Double] {
        (0..<count).map { index in
            let phase = Double(index)
            let envelope = 0.55 + 0.4 * sin(phase * 0.05)
            let detail = abs(sin(phase * 0.5) * cos(phase * 0.13)) + 0.3 * abs(sin(phase * 1.1))
            return min(1.0, max(0.06, envelope * detail))
        }
    }
}
