import Foundation

extension Song {
    /// In-memory demo song — the generated arpeggio (`SampleToneGenerator`) is its
    /// audio. Seeded into the store on first launch and used by previews.
    /// `bookmark == nil` flags it as the sample (no real file behind it).
    static func sample() -> Song {
        let duration: TimeInterval = 30
        let song = Song(title: "Little Wing", artist: "Jimi Hendrix",
                        album: "Axis: Bold as Love", year: 1967, key: "G minor",
                        bpm: 76, proficiency: 3, progression: "Groove / lead phrasing",
                        collections: ["Hendrix study", "Bends & vibrato"],
                        comment: "Watch the thumb-over chord voicings in the intro.",
                        duration: duration, amplitudes: demoAmplitudes(count: 120),
                        ref: SongRef(id: "sample", source: .localFile, bookmark: nil))
        let loops = [
            Loop(name: "Verse riff", start: 0.29, end: 0.47, speed: 0.75, repeats: 4),
            Loop(name: "Chorus bend", start: 0.62, end: 0.71, speed: 1.0, repeats: 2)
        ]
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
