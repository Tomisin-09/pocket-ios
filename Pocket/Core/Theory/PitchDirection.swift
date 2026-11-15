import Foundation

/// **Which way a note went** from the one before (ADR 0301): higher, the same, or lower. The contour,
/// the step between counting a pass and naming it that ear-training dictation teaches first.
///
/// **Always the player's word, never the app's**, like `PieceLabel`. Nothing works one out from the audio,
/// and nothing compares an answer with it. On the neck it only dims the spots the note can't be, by
/// arithmetic on the player's own answer for the note before (`NeckNarrowing`); a dimmed spot still takes a
/// tap, and placing a note takes its arrow off (D4).
///
/// Pure and SwiftUI-free (AGENTS.md), so what fits, what survives a change and the words are unit-tested.
enum PitchDirection: String, CaseIterable, Sendable {
    case higher, same, lower

    /// The button's word (D7).
    var title: String {
        switch self {
        case .higher: "Higher"
        case .same: "Same"
        case .lower: "Lower"
        }
    }

    /// The button's symbol, which a chip with an arrow shows beside its number.
    var symbol: String {
        switch self {
        case .higher: "arrow.up"
        case .same: "equal"
        case .lower: "arrow.down"
        }
    }

    /// Whether a pitch fits this direction from the note before, both MIDI notes.
    func fits(_ pitch: Int, from reference: Int) -> Bool {
        switch self {
        case .higher: pitch > reference
        case .same: pitch == reference
        case .lower: pitch < reference
        }
    }

    /// The direction said from a note: *Higher than note 5*, *The same as note 5*. `number` is 1-based.
    func spoken(from number: Int, noun: String) -> String {
        "\(lead) \(noun) \(number)"
    }

    /// What a chip with this arrow adds for VoiceOver: *heard higher*.
    var heard: String {
        switch self {
        case .higher: "heard higher"
        case .same: "heard the same"
        case .lower: "heard lower"
        }
    }

    /// The start of a sentence comparing with a note: *Higher than*, *The same as*.
    private var lead: String {
        switch self {
        case .higher: "Higher than"
        case .same: "The same as"
        case .lower: "Lower than"
        }
    }
}

// MARK: - The note before

extension PitchDirection {

    /// What the note before the one being named is, to compare with (D3, D5).
    enum Before: Equatable, Sendable {
        /// The first note: there's nothing before it.
        case nothing
        /// Not placed yet. An arrow waits until it is.
        case unplaced
        /// A dead note, with no pitch.
        case muted
        /// A shape: several notes, with no one pitch.
        case severalNotes
        /// A name given by ear, with no octave.
        case byEar
        /// One note on the neck: where it is, and the pitch it lands on, the pitch it's named by (ADR 0288
        /// D2). A held bend counts at its bent pitch, a released one at its own fret.
        case note(NeckSpot, midi: Int)
    }

    /// What the note before `index` is, in `labels`, on strings tuned to `openMidi`.
    static func before(_ index: Int, in labels: [PieceLabel?], openMidi: [Int]) -> Before {
        guard index > 0, labels.indices.contains(index - 1) else { return .nothing }
        guard let label = labels[index - 1] else { return .unplaced }
        if label.isMuted { return .muted }
        switch label {
        case .pitchClass, .chord, .muted:
            return .byEar
        case .fretted(let notes, _, _):
            guard notes.count == 1 else { return .severalNotes }
            // A fret past the strings it was written against can't be placed again until it's fixed, so it
            // reads as not placed.
            guard let midi = notes[0].sounding(openMidi: openMidi) else { return .unplaced }
            return .note(NeckSpot(string: notes[0].string, fret: notes[0].fret), midi: midi)
        }
    }
}

// MARK: - Which arrows survive a change to the pass

extension PitchDirection {

    /// The arrows that still mean what they said after the pass changed from `old` to `new` (D6), each kept
    /// with its tap's time. An arrow goes when its tap is answered or its answer changes (placing wins,
    /// D4), when its tap is taken out, and when **the note before it** is no longer the same tap, because a
    /// correction put one in or took one out just before it: the note it was compared with has gone.
    static func kept(_ arrows: [TimeInterval: PitchDirection], from old: [PieceTranscription.Tap],
                     to new: [PieceTranscription.Tap]) -> [TimeInterval: PitchDirection] {
        guard !arrows.isEmpty else { return arrows }
        let oldIndex = Dictionary(old.indices.map { (old[$0].seconds, $0) }, uniquingKeysWith: { first, _ in first })
        let newIndex = Dictionary(new.indices.map { (new[$0].seconds, $0) }, uniquingKeysWith: { first, _ in first })
        return arrows.filter { seconds, _ in
            guard let was = oldIndex[seconds], let now = newIndex[seconds] else { return false }
            guard old[was].label == new[now].label else { return false }
            let beforeThen = was > 0 ? old[was - 1].seconds : nil
            let beforeNow = now > 0 ? new[now - 1].seconds : nil
            return beforeThen == beforeNow
        }
    }
}

// MARK: - What it says (D7)

extension PitchDirection {

    /// The row's left end: *From note 5 · D*, *From note 5* when the note before has no one pitch, or
    /// *Note 1 has nothing before it*. `index` is the note being named, 0-based.
    static func rowTitle(at index: Int, before: Before, noun: String, spelling: NoteSpelling) -> String {
        switch before {
        case .nothing:
            return "\(noun.capitalized) \(index + 1) has nothing before it"
        case .note(_, let midi):
            return "From \(noun) \(index) · \(spelling.name(pitchClass: PieceLabel.normalised(midi)))"
        case .unplaced, .muted, .severalNotes, .byEar:
            return "From \(noun) \(index)"
        }
    }

    /// The line under the neck while this arrow is lit on the note at `index`, 0-based, or `nil` on the
    /// first note, which can't hold one.
    func caption(at index: Int, before: Before, noun: String, spelling: NoteSpelling) -> String? {
        let note = "\(noun) \(index)"
        switch before {
        case .nothing:
            return nil
        case .note(_, let midi):
            let name = spelling.name(pitchClass: PieceLabel.normalised(midi))
            return "\(spoken(from: index, noun: noun)) (\(name)). The spots it can’t be are dimmed, and still "
                + "take a tap."
        case .unplaced:
            return "Nothing is dimmed until \(note) is placed."
        case .muted:
            return "\(note.capitalized) is muted, so there’s no pitch to compare with."
        case .severalNotes:
            return "\(note.capitalized) is several notes, so there’s no one pitch to compare with."
        case .byEar:
            return "\(note.capitalized) was named by ear, with no octave to compare with."
        }
    }
}

// MARK: - The dim on the neck

/// **What an arrow dims on the neck** (ADR 0301 D3): every spot whose pitch doesn't fit it from the note
/// before, and every ✕, since a muted note has no pitch. The note compared with stays bright, so the
/// reference stays readable, and so does the note's own answer. It only ever dims: the neck takes a tap on
/// a dimmed spot as on any other (D4).
struct NeckNarrowing: Equatable, Sendable {
    let direction: PitchDirection
    /// The note before's pitch, where it lands.
    let reference: Int
    /// The spots that stay bright whatever the arrow says.
    let bright: Set<NeckSpot>
    /// The strings whose ✕ stays bright: the note's own answer, when it's a muted string.
    let brightMutes: Set<Int>
    let openMidi: [Int]

    /// True for a spot the note can't be.
    func dims(string: Int, fret: Int) -> Bool {
        guard openMidi.indices.contains(string), !bright.contains(NeckSpot(string: string, fret: fret)) else {
            return false
        }
        return !direction.fits(openMidi[string] + fret, from: reference)
    }

    /// True for a string's ✕, unless the note's own answer mutes that string.
    func dimsMute(string: Int) -> Bool { !brightMutes.contains(string) }

    /// The dim for the note at `index` with `arrow` lit, or `nil` when nothing dims: no arrow, or a note
    /// before with no one pitch on the neck (D5).
    static func make(_ arrow: PitchDirection?, at index: Int, in labels: [PieceLabel?],
                     openMidi: [Int]) -> NeckNarrowing? {
        guard let arrow, case .note(let spot, let midi) = PitchDirection.before(index, in: labels, openMidi: openMidi)
        else { return nil }
        let own = labels.indices.contains(index) ? labels[index] : nil
        let ownSpots = (own?.frettedNotes ?? []).map { NeckSpot(string: $0.string, fret: $0.fret) }
        return NeckNarrowing(direction: arrow, reference: midi, bright: Set(ownSpots).union([spot]),
                             brightMutes: own?.mutedStrings ?? [], openMidi: openMidi)
    }
}
