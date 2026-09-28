import Foundation

/// What a **By ear** answer is (ADR 0227 D6): one note, or a chord of some quality. The kinds are grouped
/// by how many notes they hold, so naming a note is just the smallest case of naming by ear.
///
/// Pure and SwiftUI-free (AGENTS.md), so the grouping and the tap rules are unit-tested.
enum EarKind: Hashable, Sendable {
    /// A single note, named with no octave.
    case note
    /// A chord of this `ChordQuality` suffix (`""` major, `"m"`, `"7"`, …).
    case chord(suffix: String)

    /// One row of the sheet: the kinds that hold this many notes.
    struct Group: Equatable {
        let title: String
        let kinds: [EarKind]
    }

    /// *One note*, then the chord qualities by how many notes they hold, each in the namer's order (most
    /// common first). The qualities are `PieceLabel.chordQualities`, the catalog with each suffix once, so
    /// a 9th counts its full five-note form.
    static let groups: [Group] = {
        func chords(holding count: (Int) -> Bool) -> [EarKind] {
            PieceLabel.chordQualities.filter { count($0.intervals.count) }.map { .chord(suffix: $0.suffix) }
        }
        return [
            Group(title: "One note", kinds: [.note]),
            Group(title: "Two notes", kinds: chords { $0 == 2 }),
            Group(title: "Three notes", kinds: chords { $0 == 3 }),
            Group(title: "Four or more", kinds: chords { $0 >= 4 })
        ]
    }()

    /// What the kind's button says: *Note*, *maj* for the bare major suffix, else the suffix.
    var title: String {
        switch self {
        case .note: return "Note"
        case .chord(let suffix): return suffix.isEmpty ? "maj" : suffix
        }
    }

    /// The answer this kind makes of a pitch class: a note name, or a chord on that root.
    func label(root: Int) -> PieceLabel {
        switch self {
        case .note: return .pitchClass(root)
        case .chord(let suffix): return .chord(root: root, suffix: suffix)
        }
    }

    /// The kind an answer was **named** as, or `nil` for one placed on the neck. A placed note is read
    /// at this level (`PieceLabel.earReading`), never named.
    init?(namedAs label: PieceLabel) {
        switch label {
        case .pitchClass: self = .note
        case .chord(_, let suffix): self = .chord(suffix: suffix)
        case .fretted: return nil
        }
    }
}

/// An answer as By ear sees it (ADR 0227 D7): a root and a kind.
struct EarReading: Equatable, Sendable {
    let root: Int
    let kind: EarKind
}

extension PieceLabel {
    /// What this answer says at the By ear level. A placed note reads as the note it sounds and a shape as
    /// the chord it spells, so nothing is entered twice. `nil` when there's nothing to read: a fret past
    /// the strings it was written against, or a shape that spells no chord.
    func earReading(openMidi: [Int]) -> EarReading? {
        switch self {
        case .fretted(let notes, _) where notes.count > 1:
            return NeckShape.read(notes, openMidi: openMidi)?.chord
        case .pitchClass, .fretted:
            return pitchClass(openMidi: openMidi).map { EarReading(root: $0, kind: .note) }
        case .chord(let root, let suffix):
            return EarReading(root: root, kind: .chord(suffix: suffix))
        }
    }

    /// True for an answer placed on the neck, the work another sheet asks before overwriting (ADR 0227 D7).
    var isOnTheNeck: Bool {
        if case .fretted = self { return true }
        return false
    }
}

/// What a tap on the By ear sheet does to the current answer (ADR 0227 D6, D7). **Only overwriting neck
/// work asks first**; everything else is one tap to redo, so it just replaces.
enum EarPick: Equatable {
    /// Save this answer, and move on to the next tap when `advance`.
    case save(PieceLabel, advance: Bool)
    /// This would overwrite an answer placed on the neck: ask, offering this one instead.
    case askToReplace(PieceLabel)
    /// Nothing to change.
    case none

    /// Tapping a name with `kind` selected: it saves and moves on. Picking what the neck already reads
    /// keeps the neck's answer and moves on; picking anything else over neck work asks first.
    static func name(_ root: Int, as kind: EarKind, over current: PieceLabel?, openMidi: [Int]) -> EarPick {
        let named = kind.label(root: root)
        guard let current, current.isOnTheNeck else { return .save(named, advance: true) }
        if current.earReading(openMidi: openMidi) == EarReading(root: root, kind: kind) {
            return .save(current, advance: true)
        }
        return .askToReplace(named)
    }

    /// Tapping a kind: it changes the current answer's kind **without moving on**. An empty tap has
    /// nothing to change (the kind just stays selected for the next name), and neck work asks first
    /// unless the neck already reads as this kind.
    static func kind(_ kind: EarKind, over current: PieceLabel?, openMidi: [Int]) -> EarPick {
        guard let current, let reading = current.earReading(openMidi: openMidi) else { return .none }
        guard reading.kind != kind else { return .none }
        let named = kind.label(root: reading.root)
        return current.isOnTheNeck ? .askToReplace(named) : .save(named, advance: false)
    }
}
