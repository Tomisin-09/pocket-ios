import Foundation

/// What the player says **one tap was** (ADR 0225): a note name, notes on the neck, or a chord. One type for
/// every kind, so a piece named one way and a piece named another are the same kind of thing to the reader
/// that comes later: the song map (`docs/plans/song-map.md`), where chord pieces and note pieces sit in
/// separate lanes of the same board.
///
/// **Always the player's word, never the app's.** Nothing constructs one of these from audio. The app
/// plays back what is really at the tap and the player decides what it was (ADR 0070, 0094 T2c).
///
/// Pure and SwiftUI-free (AGENTS.md), so the pitch arithmetic is unit-tested rather than trusted.
enum PieceLabel: Equatable, Hashable, Sendable {
    /// A note name with no octave, pitch class 0…11 (C = 0). What the ear actually hears first.
    case pitchClass(Int)
    /// Notes on the neck (ADR 0227 D9): one, or a shape of up to one per string, each with the marks that
    /// live on the note, and how the tap was reached from the one before. Strings are **highest-first**
    /// (0 = the thinnest), the fretboard engine's convention (ADR 0116), and index the open strings the
    /// piece was written against (`PieceTranscription.openMidi`).
    case fretted([FrettedNote], into: Join?)
    /// A chord: a root pitch class and a `ChordQuality` suffix (`""` major, `"m"`, `"7"`, …). A chord
    /// is named the way it is heard, by root and quality, not by the grip that plays it.
    case chord(root: Int, suffix: String)

    /// One plain note on the neck, with no marks.
    static func fretted(string: Int, fret: Int) -> PieceLabel {
        .fretted([FrettedNote(string: string, fret: fret)], into: nil)
    }

    /// The highest fret the neck offers. A 22-fret neck is the common case; a note above it is a
    /// rarity the Journal text can carry.
    static let maxFret = 22

    /// The notes on the neck, or `[]` for an answer named by ear.
    var frettedNotes: [FrettedNote] {
        guard case .fretted(let notes, _) = self else { return [] }
        return notes
    }

    /// The single note, when this is one note on the neck.
    var singleNote: FrettedNote? {
        let notes = frettedNotes
        return notes.count == 1 ? notes[0] : nil
    }

    /// The pitch class this label names, or `nil` when there isn't one: a fret past the strings it was
    /// written against, or a shape that spells no chord. A placed note answers with the note it
    /// **sounds**, its bend included (ADR 0227 D9); a chord, named or placed, answers with its **root**.
    func pitchClass(openMidi: [Int]) -> Int? {
        switch self {
        case .pitchClass(let value):
            return Self.normalised(value)
        case .fretted(let notes, _):
            if notes.count > 1 { return NeckShape.read(notes, openMidi: openMidi)?.chord?.root }
            return midiNote(openMidi: openMidi).map(Self.normalised)
        case .chord(let root, _):
            return Self.normalised(root)
        }
    }

    /// The MIDI note a single placed note sounds, bend included, or `nil` for any other kind (a bare
    /// name has no octave, and a chord or shape is several notes) or a string outside `openMidi`.
    func midiNote(openMidi: [Int]) -> Int? {
        singleNote?.sounding(openMidi: openMidi)
    }

    /// How the label reads in a line of names, e.g. `"D♯"`, `"Am7"`. A placed note reads as the note it
    /// sounds, and a shape as what it spells (`"Am/C"`, or `"4th"` for a double-stop that isn't a chord);
    /// `nil` only when that can't be worked out.
    func name(openMidi: [Int], spelling: NoteSpelling) -> String? {
        switch self {
        case .chord(let root, let suffix):
            return spelling.name(pitchClass: root) + suffix
        case .fretted(let notes, _) where notes.count > 1:
            return NeckShape.read(notes, openMidi: openMidi)?.shortName(spelling: spelling)
        case .pitchClass, .fretted:
            return pitchClass(openMidi: openMidi).map { spelling.name(pitchClass: $0) }
        }
    }

    /// True for a chord label. The count's noun follows it ("4 chords").
    var isChord: Bool {
        if case .chord = self { return true }
        return false
    }

    /// The chord qualities offered when naming a chord, most common first, **one per suffix**. The
    /// namer's catalog lists each 9th twice (with and without its 5th), which a picker must not.
    static let chordQualities: [ChordQuality] = ChordQuality.catalog.reduce(into: []) { kept, quality in
        if !kept.contains(where: { $0.suffix == quality.suffix }) { kept.append(quality) }
    }

    static func normalised(_ value: Int) -> Int { ((value % 12) + 12) % 12 }
}

/// One note on the neck, with the marks that live **on** the note (ADR 0227 D5): a bend changes the note
/// (the sounding pitch moves, so without it a bent note has no right fret), and vibrato colours it.
struct FrettedNote: Equatable, Hashable, Sendable {
    /// Highest-first: 0 is the thinnest string.
    var string: Int
    var fret: Int
    /// Semitones the note is bent up: 0 none, then ½, whole and 1½ steps.
    var bend: Int = 0
    var vibrato = false

    /// The bends the neck offers, in semitones.
    static let bends = 0...3

    /// The note it sounds, bend included, or `nil` for a string outside `openMidi`.
    func sounding(openMidi: [Int]) -> Int? {
        openMidi.indices.contains(string) ? openMidi[string] + fret + bend : nil
    }
}

/// How a tap was reached from the tap before (ADR 0227 D5): hammered or pulled (**legato**), or slid.
/// Which of hammer-on or pull-off, `/` or `\`, is worked out from the direction, never stored, so it can't
/// disagree with the frets.
enum Join: String, Codable, Sendable, CaseIterable {
    case legato, slide
}

// MARK: - Coding

/// A tagged object per label (`{"kind": "note", "pitchClass": 3}`) rather than Swift's synthesised enum
/// coding. The archive is meant to be readable (ADR 0188), and a tag is what lets an older build meet a
/// kind it has never heard of and drop just that label (`PieceTranscription.Tap` decodes it with
/// `try?`) instead of failing the whole piece.
///
/// **One note on the neck is written as 0225's `fret` kind** with its marks as optional keys, so an older
/// build keeps the fret and drops the marks: a note without its bend is still where it was played. **Two
/// or more are a `shape`**, which an older build reads as an unnamed tap: a chord cut down to one note
/// would be a wrong answer, and no answer is better than that (ADR 0227 D9).
extension PieceLabel: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, pitchClass, string, fret, bend, vibrato, into, notes, root, suffix
    }

    private enum Kind: String, Codable {
        case note, fret, shape, chord
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .note:
            self = .pitchClass(Self.normalised(try container.decode(Int.self, forKey: .pitchClass)))
        case .fret:
            self = .fretted([try FrettedNote(from: decoder)], into: try Self.join(in: container))
        case .shape:
            let notes = try container.decode([FrettedNote].self, forKey: .notes)
            guard notes.count > 1 else { throw DecodingError.dataCorruptedError(
                forKey: .notes, in: container, debugDescription: "A shape holds two notes or more.") }
            self = .fretted(notes, into: try Self.join(in: container))
        case .chord:
            self = .chord(root: Self.normalised(try container.decode(Int.self, forKey: .root)),
                          suffix: try container.decode(String.self, forKey: .suffix))
        }
    }

    /// A join this build doesn't know reads as no join, not a lost answer.
    private static func join(in container: KeyedDecodingContainer<CodingKeys>) throws -> Join? {
        (try container.decodeIfPresent(String.self, forKey: .into)).flatMap(Join.init(rawValue:))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pitchClass(let value):
            try container.encode(Kind.note, forKey: .kind)
            try container.encode(value, forKey: .pitchClass)
        case .fretted(let notes, let into):
            if notes.count == 1 {
                try container.encode(Kind.fret, forKey: .kind)
                try notes[0].encode(to: encoder)
            } else {
                try container.encode(Kind.shape, forKey: .kind)
                try container.encode(notes, forKey: .notes)
            }
            try container.encodeIfPresent(into, forKey: .into)
        case .chord(let root, let suffix):
            try container.encode(Kind.chord, forKey: .kind)
            try container.encode(root, forKey: .root)
            try container.encode(suffix, forKey: .suffix)
        }
    }
}

/// A note's keys: `string` and `fret` always, `bend` and `vibrato` only when set, so an unmarked note is
/// written exactly as 0225 wrote it.
extension FrettedNote: Codable {
    private enum CodingKeys: String, CodingKey {
        case string, fret, bend, vibrato
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        string = try container.decode(Int.self, forKey: .string)
        fret = try container.decode(Int.self, forKey: .fret)
        let bend = try container.decodeIfPresent(Int.self, forKey: .bend) ?? 0
        self.bend = Self.bends.contains(bend) ? bend : 0
        vibrato = try container.decodeIfPresent(Bool.self, forKey: .vibrato) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(string, forKey: .string)
        try container.encode(fret, forKey: .fret)
        if bend != 0 { try container.encode(bend, forKey: .bend) }
        if vibrato { try container.encode(vibrato, forKey: .vibrato) }
    }
}
