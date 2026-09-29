import Foundation

/// A song laid out enough to show every part of the map (ADR 0232): sections and a pin, chords and notes
/// pieces in each state D4 draws, and two notes pieces overlapping. For the preview and the snapshot test.
/// The demo song's names and artist (`Song.sample`), which name nobody real.
enum SongMapPreview {
    private static let bpm = 90.0
    private static let standard = [64, 59, 55, 50, 45, 40]

    /// Where bar `number` starts, 1-based, at 90 BPM in 4/4 with the 1 at 0:00.
    private static func bar(_ number: Double) -> TimeInterval { (number - 1) * 60 / bpm * 4 }

    static func song() -> Song {
        let duration = bar(33)
        let song = Song(title: "Slow Bend", artist: "Jack Trader", album: "Demos", year: 2024,
                        key: MusicalKey.gMinor.rawValue, bpm: Int(bpm), collections: [],
                        duration: duration, amplitudes: Song.demoAmplitudes(count: 120),
                        ref: SongRef(id: "sample", source: .localFile, bookmark: nil))
        song.downbeatSeconds = 0

        let verse = section(bar(5), "Verse 1"), verseAgain = section(bar(21), "Verse 2")
        verseAgain.sameAsUID = verse.uid
        let markers = [section(bar(1), "Intro"), verse,
                       Marker(seconds: bar(9), label: "Tricky bend"),
                       section(bar(13), "Chorus"), verseAgain, section(bar(29), "Outro")]

        let verseChords = ["Gm7", "C7", "Gm7", "Gm7", "C7", "C7", "Gm7", "D7"].enumerated().map { index, name in
            PieceTranscription.Tap(seconds: bar(5 + Double(index)), label: chord(name))
        }
        let riffFrets = [(3, 3), (3, 5), (2, 3), (2, 5), (1, 3), (1, 6), (1, 3), (2, 5)]
        let verseRiff = riffFrets.enumerated().map { index, fret in
            PieceTranscription.Tap(seconds: bar(9) + Double(index) * 0.33,
                                   label: index < 5 ? .fretted(string: fret.0, fret: fret.1) : nil)
        }
        let counted = (0..<9).map { PieceTranscription.Tap(seconds: bar(13) + Double($0) * 0.6) }

        let loops = [
            loop("Intro changes", from: bar(1), to: bar(3), duration: duration, type: .chords,
                 piece: PieceTranscription(taps: [.init(seconds: bar(1), label: chord("Gm7")),
                                                  .init(seconds: bar(2), label: chord("C7"))])),
            loop("Verse changes", from: bar(5), to: bar(13), duration: duration, type: .chords,
                 piece: PieceTranscription(taps: verseChords)),
            loop("Verse riff", from: bar(9), to: bar(11), duration: duration, type: .riff,
                 piece: PieceTranscription(taps: verseRiff, openMidi: standard, tuningLabel: "Guitar · Standard")),
            loop("Chorus hook", from: bar(13), to: bar(17), duration: duration, type: .lick,
                 piece: PieceTranscription(taps: counted)),
            loop("Chorus bend", from: bar(15), to: bar(18), duration: duration, type: .lick),
            loop("Solo opener", from: bar(29), to: bar(31), duration: duration, type: .lick)
        ]
        let tagged = JournalEntry(text: "Worked it out on paper.", kind: .transcribed,
                                  masteryAtEntry: nil, commandTempoAtEntry: nil)
        loops[5].journal = [tagged]
        // One progression, worked out once, that the intro plays twice (ADR 0232 D14).
        loops[0].repeatsToSectionEnd = true

        song.loops = loops
        song.markers = markers
        for loop in loops { loop.song = song }
        for marker in markers { marker.song = song }
        return song
    }

    private static func section(_ seconds: TimeInterval, _ label: String) -> Marker {
        let marker = Marker(seconds: seconds, label: label)
        marker.startsSection = true
        return marker
    }

    private static func chord(_ name: String) -> PieceLabel {
        switch name {
        case "Gm7": .chord(root: 7, suffix: "m7")
        case "C7": .chord(root: 0, suffix: "7")
        default: .chord(root: 2, suffix: "7")
        }
    }

    private static func loop(_ name: String, from start: TimeInterval, to end: TimeInterval,
                             duration: TimeInterval, type: LoopType, piece: PieceTranscription? = nil) -> Loop {
        let loop = Loop(name: name, start: start / duration, end: end / duration, speed: 1, repeats: 4)
        loop.loopType = type
        loop.transcription = piece
        return loop
    }
}
