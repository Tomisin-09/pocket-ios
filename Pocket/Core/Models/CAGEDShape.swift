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
