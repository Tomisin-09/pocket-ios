import Foundation

/// The chords under what's watched (ADR 0308 D4–D6), named and read against the song's key: what colours
/// each tap, what each chip says over the first of its chord, and what the row over the neck says now and
/// next.
///
/// Pure and Foundation-only (AGENTS.md), unit-tested in `WatchChordsTests`. The colour itself is a view's
/// business (`PocketColor.chord(degree:)`); this says which degree, or none.
struct WatchChords: Equatable, Sendable {

    struct Chord: Equatable, Sendable {
        let seconds: TimeInterval
        let until: TimeInterval
        /// *Am*, spelled for the song's key.
        let name: String
        /// The numeral and degree, or `nil` with no key set (D6): then a name with no colour.
        let numeral: ChordNumeral?

        /// *Am · i*, or *Am* with no key.
        var title: String { numeral.map { "\(name) · \($0.numeral)" } ?? name }
    }

    /// One after another, the same chord played again in a row held as one.
    let chords: [Chord]

    init(_ chords: [SectionWatch.Chord], key: MusicalKey, spelling: NoteSpelling) {
        var held: [SectionWatch.Chord] = []
        for chord in chords {
            if let last = held.last, last.root == chord.root, last.suffix == chord.suffix,
               abs(last.until - chord.seconds) < 0.001 {
                held[held.count - 1] = SectionWatch.Chord(seconds: last.seconds, until: chord.until,
                                                          root: last.root, suffix: last.suffix)
            } else {
                held.append(chord)
            }
        }
        self.chords = held.map { chord in
            let numeral = ChordNumeral.read(root: chord.root, suffix: chord.suffix, in: key)
            // A root outside the key is spelled as its numeral says: B♭ for ♭II, never A♯.
            let spelled: NoteSpelling = switch numeral?.numeral.first {
            case "♭": .flats
            case "♯": .sharps
            default: spelling
            }
            return Chord(seconds: chord.seconds, until: chord.until,
                         name: spelled.name(pitchClass: chord.root) + chord.suffix, numeral: numeral)
        }
    }

    /// The chord the song is on at `time`, or `nil` where none plays (D4: the notes are drawn as they are).
    func index(at time: TimeInterval) -> Int? {
        chords.lastIndex { $0.seconds <= time + 0.001 && time < $0.until }
    }

    /// What comes after the chord at `index`: *then G · VII*. `nil` at the last.
    func next(after index: Int) -> Chord? {
        chords.indices.contains(index + 1) ? chords[index + 1] : nil
    }

    /// Each tap's chord, by when it's played.
    func chordIndices(of taps: [TimeInterval]) -> [Int?] {
        taps.map(index(at:))
    }

    /// Whether the tap at `position` is the first of its chord, so its chip carries the chord's name and
    /// numeral (D4).
    static func startsAChord(_ indices: [Int?], at position: Int) -> Bool {
        guard indices.indices.contains(position), let chord = indices[position] else { return false }
        return position == 0 || indices[position - 1] != chord
    }

    /// Is there a key to read numerals against? Without one, chords show their names alone, and the sheet
    /// offers **Set the key** (D6).
    var hasNumerals: Bool { chords.contains { $0.numeral != nil } }
}
