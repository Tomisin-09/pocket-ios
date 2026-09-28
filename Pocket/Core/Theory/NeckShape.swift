import Foundation

/// What a **shape** on the neck reads as (ADR 0227 D4): a chord, through the chord namer (ADR 0093) with
/// root position preferred and an inversion as a slash name (*Am/C*), or, for a double-stop that isn't a
/// power chord, its **interval** (*a 4th*). It names what was placed, never what was heard.
///
/// Pure and SwiftUI-free (AGENTS.md), so the naming is unit-tested.
struct ShapeReading: Equatable, Sendable {
    /// *Double-stop*, *Power chord*, *Triad* or *Chord*, for the line under the neck.
    let word: String
    /// The chord it spells, when it spells one.
    let chord: EarReading?
    /// The lowest sounding pitch class, for a slash name.
    let bass: Int
    /// For a double-stop that isn't a chord: the gap between its two notes, in semitones (0 a unison).
    let semitones: Int?
    /// The distinct pitch classes, lowest first.
    let pitchClasses: [Int]

    /// How the reading is said: the chord's name (*Am/C*), the interval (*a 4th*), or *no common chord
    /// name*.
    func name(spelling: NoteSpelling) -> String {
        if let chord, case .chord(let suffix) = chord.kind {
            let slash = bass == chord.root ? "" : "/" + spelling.name(pitchClass: bass)
            return spelling.name(pitchClass: chord.root) + suffix + slash
        }
        if let semitones { return NeckShape.intervalName(semitones) }
        return "no common chord name"
    }

    /// The short form a chip has room for: the chord's name, the interval (*4th*), or the notes.
    func shortName(spelling: NoteSpelling) -> String {
        if chord != nil { return name(spelling: spelling) }
        if let semitones { return NeckShape.intervalChip(semitones) }
        return pitchClasses.map { spelling.name(pitchClass: $0) }.joined(separator: "·")
    }
}

enum NeckShape {

    /// Read a shape of two or more notes against the strings it was placed on. `nil` for fewer than two
    /// notes, or any note off the strings.
    static func read(_ notes: [FrettedNote], openMidi: [Int]) -> ShapeReading? {
        let sounding = notes.compactMap { $0.sounding(openMidi: openMidi) }
        guard notes.count > 1, sounding.count == notes.count, let lowest = sounding.min() else { return nil }
        let bass = PieceLabel.normalised(lowest)
        var classes: [Int] = []
        for midi in sounding.sorted() where !classes.contains(PieceLabel.normalised(midi)) {
            classes.append(PieceLabel.normalised(midi))
        }
        let best = ChordNamer.candidates(pitchClasses: Set(classes), bassPitchClass: bass).first
        let word = notes.count == 2 ? "Double-stop" : notes.count == 3 && classes.count == 3 ? "Triad" : "Chord"
        // A power chord upside down, its 5th under its root, is a 4th, not "A5/E".
        if let best, !(best.quality.suffix == "5" && best.rootPitchClass != bass) {
            return ShapeReading(word: best.quality.suffix == "5" ? "Power chord" : word,
                                chord: EarReading(root: best.rootPitchClass, kind: .chord(suffix: best.quality.suffix)),
                                bass: bass, semitones: nil, pitchClasses: classes)
        }
        let gap = notes.count == 2 ? abs(sounding[0] - sounding[1]) : nil
        return ShapeReading(word: word, chord: nil, bass: bass, semitones: gap, pitchClasses: classes)
    }

    /// An interval in words, reduced within the octave: *a minor 3rd*, *a 4th*, *an octave*.
    static func intervalName(_ semitones: Int) -> String {
        semitones == 0 ? "a unison" : intervalNames[semitones % 12]
    }

    /// An interval as short as a chip: *min 3rd*, *4th*, *8ve*. Never *m3* or *m7*: on By ear those
    /// read as chord qualities.
    static func intervalChip(_ semitones: Int) -> String {
        semitones == 0 ? "unison" : intervalChips[semitones % 12]
    }

    /// The twelve interval names, by semitones within the octave. The app had degree labels (♭3, 5)
    /// but no interval names in words.
    private static let intervalNames = ["an octave", "a minor 2nd", "a major 2nd", "a minor 3rd", "a major 3rd",
                                        "a 4th", "a tritone", "a 5th", "a minor 6th", "a major 6th",
                                        "a minor 7th", "a major 7th"]
    private static let intervalChips = ["8ve", "min 2nd", "maj 2nd", "min 3rd", "maj 3rd", "4th", "tritone", "5th",
                                        "min 6th", "maj 6th", "min 7th", "maj 7th"]
}

/// What a tap on the neck does to the answer being named (ADR 0227 D3, D4). Pure, so the one-note-per-string
/// rule the My chords placer uses is tested here rather than by hand.
enum NeckPlacement {

    /// The answer after a tap, and which string's note is **ringed** (the one bend and vibrato go on).
    struct Outcome: Equatable {
        let label: PieceLabel
        let ringed: Int
    }

    /// With **Chords** off a tap replaces the note, and the note keeps its marks, its lead-in too while it
    /// stays on its string; tapping the placed note changes nothing. With Chords on, one note per string:
    /// a tap on an empty string adds a note, on a string with one moves it, and on a note rings it, then,
    /// tapped again, takes it out (unless it's the last). A join is kept, for the sheet's tidy to drop if
    /// it no longer fits.
    static func tap(string: Int, fret: Int, on current: PieceLabel?, ringed: Int?, chords: Bool) -> Outcome {
        guard case .fretted(var notes, let into) = current, !notes.isEmpty else {
            return Outcome(label: .fretted(string: string, fret: fret), ringed: string)
        }
        let ring = notes.firstIndex { $0.string == ringed } ?? notes.count - 1
        guard chords else {
            if notes.count == 1, notes[0].string == string, notes[0].fret == fret {
                return Outcome(label: .fretted(notes, into: into), ringed: string)
            }
            let kept = notes[ring]
            return Outcome(label: .fretted([FrettedNote(string: string, fret: fret, bend: kept.bend,
                                                        vibrato: kept.vibrato,
                                                        leadIn: kept.string == string ? kept.leadIn : nil)],
                                           into: into),
                           ringed: string)
        }
        if let onString = notes.firstIndex(where: { $0.string == string }) {
            if notes[onString].fret != fret {
                notes[onString].fret = fret
            } else if onString == ring, notes.count > 1 {
                notes.remove(at: onString)
                return Outcome(label: .fretted(notes, into: into), ringed: notes[notes.count - 1].string)
            }
            return Outcome(label: .fretted(notes, into: into), ringed: string)
        }
        notes.append(FrettedNote(string: string, fret: fret))
        return Outcome(label: .fretted(notes, into: into), ringed: string)
    }
}
