import Foundation

/// The five **CAGED positions** of the major scale (ADR 0065 build 2, Slice 2 rebuild). Each case is a
/// hand "box" — the major-scale note positions in one region of the neck — encoded once in the
/// reference key of **A** (root pitch class 9). Because a fretboard shape is key-independent, every
/// other key is the same box slid up or down; and because a scale or arpeggio is just a subset of the
/// major scale, every pentatonic, diatonic and arpeggio shape is this one box **filtered** to its
/// interval formula. Five geometries therefore encode every shape, correct by construction — the fix
/// for the formula generator that only held together at the E position.
///
/// Positions are numbered the way the CAGED reference numbers them: **E-shape = 1**, then D, C, A, G
/// climbing the neck. Minor-family scales reuse these boxes via their *relative major* root, so a
/// shape is never authored twice.
enum CAGEDShape: Int, CaseIterable, Identifiable {
    case position1 = 1   // E shape
    case position2       // D shape
    case position3       // C shape
    case position4       // A shape
    case position5       // G shape

    var id: Int { rawValue }

    /// The CAGED reference letter for this box — what a player actually recognises the shape as. Shown
    /// in the editors instead of a bare "Position N" so the numbering reads the way guitarists already
    /// think about it (a fixed E-shape=1…G-shape=5 index, not the classic minor-pentatonic box order).
    var shapeLetter: String {
        switch self {
        case .position1: return "E"
        case .position2: return "D"
        case .position3: return "C"
        case .position4: return "A"
        case .position5: return "G"
        }
    }

    /// The reference key the boxes are authored in — A major (pitch class 9).
    static let referenceRoot = 9

    /// The nearest valid position for a raw index (clamped to 1…5).
    init(clampedPosition raw: Int) {
        self = CAGEDShape(rawValue: min(max(1, raw), CAGEDShape.allCases.count)) ?? .position1
    }

    /// The major-scale box in the reference key (A), as `(string, fret)` notes — string 0 = high e …
    /// 5 = low E. Authored ascending by string; the generator re-sorts by pitch, so exact order here
    /// is only for readability. Every box holds all seven scale degrees across ~two octaves.
    var referenceNotes: [FretNote] {
        switch self {
        case .position1:   // E shape · frets 4–7
            return Self.build([5: [4, 5, 7], 4: [4, 5, 7], 3: [4, 6, 7],
                               2: [4, 6, 7], 1: [5, 7], 0: [4, 5, 7]])
        case .position2:   // D shape · frets 6–10 (leans: the fifth sits on the G string, not the D)
            return Self.build([5: [7, 9, 10], 4: [7, 9], 3: [6, 7, 9],
                               2: [6, 7, 9], 1: [7, 9, 10], 0: [7, 9, 10]])
        case .position3:   // C shape · frets 9–13
            return Self.build([5: [9, 10, 12], 4: [9, 11, 12], 3: [9, 11, 12],
                               2: [9, 11, 13], 1: [9, 10, 12], 0: [9, 10, 12]])
        case .position4:   // A shape · frets 11–14
            return Self.build([5: [12, 14], 4: [11, 12, 14], 3: [11, 12, 14],
                               2: [11, 13, 14], 1: [12, 14], 0: [12, 14]])
        case .position5:   // G shape · frets 2–6
            return Self.build([5: [2, 4, 5], 4: [2, 4, 5], 3: [2, 4, 6],
                               2: [2, 4, 6], 1: [2, 3, 5], 0: [2, 4, 5]])
        }
    }

    private static func build(_ byString: [Int: [Int]]) -> [FretNote] {
        byString.sorted { $0.key > $1.key }.flatMap { string, frets in
            frets.map { FretNote(string: string, fret: $0) }
        }
    }
}

// MARK: - Shared placement + filtering (pure — used by scales and arpeggios)

extension CAGEDShape {
    /// Open-string MIDI notes by our string index (5 = low E … 0 = high e).
    static let openMidi = [64, 59, 55, 50, 45, 40]

    /// The MIDI pitch of a note in standard tuning.
    static func midi(_ note: FretNote) -> Int { openMidi[note.string] + note.fret }

    /// The interval (semitones above `root`, 0…11) sounding at a note.
    static func degree(of note: FretNote, root: Int) -> Int {
        (((GuitarScale.pitchClass(string: note.string, fret: note.fret) - root) % 12) + 12) % 12
    }

    /// The conventional name of a string by our index (5 = low E … 0 = high e), as a player says it.
    static func stringName(_ string: Int) -> String {
        ["high e", "B", "G", "D", "A", "low E"][min(max(0, string), 5)]
    }

    /// The **flagship box** for a scale/arpeggio in a key (ADR 0091): the root-position 6th-string box a
    /// player learns first — the famous 5th-fret box for the minor pentatonic, which is the G-shape /
    /// position 5 here, *not* position 1. Defined as the box whose ascending run **begins on the tonic
    /// on the low E (6th) string**, tie-broken to the lowest starting fret. A box can *pass through* a
    /// low-E root without starting there (position 4's A-shape tops out on the root at fret 5 but opens
    /// on the ♭7 below it), so "begins on" — the first note played — is what picks the shape a player
    /// recognises. Falls back to the lowest low-E root, then position 1, for scales whose 6th-string box
    /// doesn't open on the tonic. Drives the default and the "Most common" badge.
    static func flagshipPosition(root: Int, relativeMajorSemitones: Int, degrees: Set<Int>) -> Int {
        let lowE = 5
        var opensOnRoot: (fret: Int, position: Int)?
        var lowestLowERoot: (fret: Int, position: Int)?
        for position in 1...allCases.count {
            // `filteredBox` returns the box ascending by pitch, so `first` is the note the run opens on.
            let box = filteredBox(position: position, root: root,
                                  relativeMajorSemitones: relativeMajorSemitones, degrees: degrees)
            if let start = box.first, start.string == lowE, degree(of: start, root: root) == 0,
               start.fret < (opensOnRoot?.fret ?? Int.max) {
                opensOnRoot = (start.fret, position)
            }
            if let fret = box.filter({ $0.string == lowE && degree(of: $0, root: root) == 0 })
                .map(\.fret).min(), fret < (lowestLowERoot?.fret ?? Int.max) {
                lowestLowERoot = (fret, position)
            }
        }
        return opensOnRoot?.position ?? lowestLowERoot?.position ?? 1
    }

    /// A **plain-language anchor** for a box (ADR 0091): where its lowest root note sits, e.g.
    /// "root on low E · fret 5" — the concrete location shown in place of a CAGED letter, so a player
    /// reads a box by where their hand goes rather than by a shape name they may not know. Reads the
    /// generated notes, so it stays true for every scale, quality and key. Falls back to the lowest
    /// fretted note when a run holds no root (a one-octave box trim can omit it).
    static func rootAnchor(in notes: [FretNote], root: Int) -> String {
        guard let anchor = notes.filter({ degree(of: $0, root: root) == 0 })
            .min(by: { midi($0) < midi($1) }) else {
            let fret = notes.map(\.fret).filter { $0 > 0 }.min() ?? notes.map(\.fret).min() ?? 1
            return "from fret \(fret)"
        }
        return anchor.fret == 0
            ? "root: open \(stringName(anchor.string))"
            : "root on \(stringName(anchor.string)) · fret \(anchor.fret)"
    }

    /// Place the `position` box for a run whose tonic is `root`, borrowing the CAGED boxes of the
    /// relative major `relativeMajorSemitones` above it, and keep the notes whose interval above the
    /// tonic is in `degrees` — a scale, a pentatonic, or an arpeggio, all the same box filtered
    /// differently. Ascending, with G–B-boundary unisons de-duped (thinner string kept) so a run
    /// never repeats a pitch.
    static func filteredBox(position: Int, root: Int,
                            relativeMajorSemitones: Int, degrees: Set<Int>) -> [FretNote] {
        let majorRoot = (((root + relativeMajorSemitones) % 12) + 12) % 12
        let delta = (((majorRoot - referenceRoot) % 12) + 12) % 12
        let placed = CAGEDShape(clampedPosition: position).referenceNotes
            .map { FretNote(string: $0.string, fret: $0.fret + delta) }
        let inScale = dropToPlayableRegion(placed)
            .filter { degrees.contains(degree(of: $0, root: root)) }
            .sorted { lhs, rhs in
                midi(lhs) != midi(rhs) ? midi(lhs) < midi(rhs) : lhs.string < rhs.string
            }
        return dedupingUnisons(inScale)
    }

    /// Keep the run to `octaves` octaves: the whole box for two, its lower octave for one.
    static func trimmed(_ notes: [FretNote], toOctaves octaves: Int) -> [FretNote] {
        guard octaves < 2, let low = notes.first.map(midi) else { return notes }
        return notes.filter { midi($0) <= low + 12 }
    }

    /// Slide a transposed box down whole octaves until its lowest note sits within the first twelve
    /// frets, so a shape stays on the neck and near the nut whatever the key.
    private static func dropToPlayableRegion(_ notes: [FretNote]) -> [FretNote] {
        guard let low = notes.map(\.fret).min(), low > 11 else { return notes }
        let drop = (low / 12) * 12
        return notes.map { FretNote(string: $0.string, fret: $0.fret - drop) }
    }

    /// Drop repeated pitches (a box can voice the same note on neighbouring strings, e.g. across the
    /// G–B boundary); keep the one on the thinner string so a linear run keeps climbing. Assumes the
    /// notes are already ordered by pitch then string.
    private static func dedupingUnisons(_ notes: [FretNote]) -> [FretNote] {
        var result: [FretNote] = []
        for note in notes where midi(note) != result.last.map(midi) {
            result.append(note)
        }
        return result
    }
}
