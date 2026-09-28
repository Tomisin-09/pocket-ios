import Foundation

/// What the player says **one tap was** (ADR 0225): a note name, a fretted note, or a chord. One type for
/// all three from the first build, so a piece named one way and a piece named another are the same kind
/// of thing to the reader that comes later: the song map (`docs/plans/song-map.md`), where chord pieces
/// and note pieces sit in separate lanes of the same board.
///
/// **Always the player's word, never the app's.** Nothing constructs one of these from audio. The app
/// plays back what is really at the tap and the player decides what it was (ADR 0070, 0094 T2c).
///
/// Pure and SwiftUI-free (AGENTS.md), so the pitch arithmetic is unit-tested rather than trusted.
enum PieceLabel: Equatable, Hashable, Sendable {
    /// A note name with no octave, pitch class 0…11 (C = 0). What the ear actually hears first.
    case pitchClass(Int)
    /// A note on the neck. `string` is **highest-first** (0 = the thinnest string), the fretboard
    /// engine's convention (ADR 0116), and indexes the open strings the piece was written against
    /// (`PieceTranscription.openMidi`). `fret` runs 0…`maxFret`.
    case fretted(string: Int, fret: Int)
    /// A chord: a root pitch class and a `ChordQuality` suffix (`""` major, `"m"`, `"7"`, …). A chord
    /// is named the way it is heard, by root and quality, not by the grip that plays it.
    case chord(root: Int, suffix: String)

    /// The highest fret the stepper offers. A 22-fret neck is the common case; a note above it is a
    /// rarity the Journal text can carry.
    static let maxFret = 22

    /// The pitch class this label names, or `nil` when a fretted note points past the strings it was
    /// written against. A chord answers with its **root**.
    func pitchClass(openMidi: [Int]) -> Int? {
        switch self {
        case .pitchClass(let value):
            return Self.normalised(value)
        case .fretted:
            return midiNote(openMidi: openMidi).map(Self.normalised)
        case .chord(let root, _):
            return Self.normalised(root)
        }
    }

    /// The single MIDI note a fretted label sounds, or `nil` for any other kind (a bare name has no
    /// octave, and a chord is several notes) or a string outside `openMidi`.
    func midiNote(openMidi: [Int]) -> Int? {
        guard case .fretted(let string, let fret) = self, openMidi.indices.contains(string) else {
            return nil
        }
        return openMidi[string] + fret
    }

    /// How the label reads in a line of names, e.g. `"D♯"`, `"Am7"`. A fretted note reads as the note
    /// it sounds; `nil` only when that can't be worked out.
    func name(openMidi: [Int], spelling: NoteSpelling) -> String? {
        switch self {
        case .chord(let root, let suffix):
            return spelling.name(pitchClass: root) + suffix
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

    private static func normalised(_ value: Int) -> Int { ((value % 12) + 12) % 12 }
}

// MARK: - Coding

/// A tagged object per label (`{"kind": "note", "pitchClass": 3}`) rather than Swift's synthesised enum
/// coding. The archive is meant to be readable (ADR 0188), and a tag is what lets an older build meet a
/// kind it has never heard of and drop just that label (`PieceTranscription.Tap` decodes it with
/// `try?`) instead of failing the whole piece.
extension PieceLabel: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, pitchClass, string, fret, root, suffix
    }

    private enum Kind: String, Codable {
        case note, fret, chord
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .note:
            self = .pitchClass(Self.normalised(try container.decode(Int.self, forKey: .pitchClass)))
        case .fret:
            self = .fretted(string: try container.decode(Int.self, forKey: .string),
                            fret: try container.decode(Int.self, forKey: .fret))
        case .chord:
            self = .chord(root: Self.normalised(try container.decode(Int.self, forKey: .root)),
                          suffix: try container.decode(String.self, forKey: .suffix))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pitchClass(let value):
            try container.encode(Kind.note, forKey: .kind)
            try container.encode(value, forKey: .pitchClass)
        case .fretted(let string, let fret):
            try container.encode(Kind.fret, forKey: .kind)
            try container.encode(string, forKey: .string)
            try container.encode(fret, forKey: .fret)
        case .chord(let root, let suffix):
            try container.encode(Kind.chord, forKey: .kind)
            try container.encode(root, forKey: .root)
            try container.encode(suffix, forKey: .suffix)
        }
    }
}
