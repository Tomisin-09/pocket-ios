import Foundation

/// The curated, **in-house** catalog of chord voicings the Chords template offers (ADR 0065, T8) —
/// generic common-practice open shapes, a few sevenths, two barre forms, and a pair of triads that
/// prove a triad is just a three-note voicing (no separate type). Frets are in the shared string
/// order: index 0 = high e … 5 = low E; `nil` muted, `0` open.
extension ChordVoicing {
    // MARK: Open major
    static let cMajor = ChordVoicing("C", frets: [0, 1, 0, 2, 3, nil], fingers: [nil, 1, nil, 2, 3, nil])
    static let aMajor = ChordVoicing("A", frets: [0, 2, 2, 2, 0, nil], fingers: [nil, 3, 2, 1, nil, nil])
    static let gMajor = ChordVoicing("G", frets: [3, 0, 0, 0, 2, 3], fingers: [4, nil, nil, nil, 1, 2])
    static let eMajor = ChordVoicing("E", frets: [0, 0, 1, 2, 2, 0], fingers: [nil, nil, 1, 3, 2, nil])
    static let dMajor = ChordVoicing("D", frets: [2, 3, 2, 0, nil, nil], fingers: [2, 3, 1, nil, nil, nil])

    // MARK: Open minor
    static let aMinor = ChordVoicing("Am", frets: [0, 1, 2, 2, 0, nil], fingers: [nil, 1, 3, 2, nil, nil])
    static let eMinor = ChordVoicing("Em", frets: [0, 0, 0, 2, 2, 0], fingers: [nil, nil, nil, 2, 3, nil])
    static let dMinor = ChordVoicing("Dm", frets: [1, 3, 2, 0, nil, nil], fingers: [1, 3, 2, nil, nil, nil])

    // MARK: Sevenths
    static let gDom7 = ChordVoicing("G7", frets: [1, 0, 0, 0, 2, 3], fingers: [1, nil, nil, nil, 2, 3])
    static let cDom7 = ChordVoicing("C7", frets: [0, 1, 3, 2, 3, nil], fingers: [nil, 1, 4, 2, 3, nil])
    static let dDom7 = ChordVoicing("D7", frets: [2, 1, 2, 0, nil, nil], fingers: [2, 1, 3, nil, nil, nil])
    static let aDom7 = ChordVoicing("A7", frets: [0, 2, 0, 2, 0, nil], fingers: [nil, 3, nil, 1, nil, nil])
    static let eDom7 = ChordVoicing("E7", frets: [0, 0, 1, 0, 2, 0], fingers: [nil, nil, 1, nil, 2, nil])
    static let cMajor7 = ChordVoicing("Cmaj7", frets: [0, 0, 0, 2, 3, nil],
                                      fingers: [nil, nil, nil, 2, 3, nil])

    // MARK: Barre
    static let fBarre = ChordVoicing("F", frets: [1, 1, 2, 3, 3, 1], fingers: [1, 1, 2, 4, 3, 1])
    static let bMinorBarre = ChordVoicing("Bm", frets: [2, 3, 4, 4, 2, nil], fingers: [1, 2, 4, 3, 1, nil])

    // MARK: Triads (a triad is just a three-note voicing — folded in, not a separate axis)
    static let cTriad = ChordVoicing("C triad", frets: [3, 5, 5, nil, nil, nil],
                                     fingers: [1, 3, 4, nil, nil, nil])
    static let aMinorTriad = ChordVoicing("Am triad", frets: [0, 1, 2, nil, nil, nil],
                                          fingers: [nil, 1, 2, nil, nil, nil])

    /// Every voicing offered in the editor's picker, grouped roughly easy → advanced.
    static let library: [ChordVoicing] = [
        .cMajor, .aMajor, .gMajor, .eMajor, .dMajor,
        .aMinor, .eMinor, .dMinor,
        .gDom7, .cDom7, .dDom7, .aDom7, .eDom7, .cMajor7,
        .fBarre, .bMinorBarre,
        .cTriad, .aMinorTriad
    ]
}

extension ChordProgression {
    /// A seeded starter: the I–V–vi–IV pop turnaround in G (G · D · Em · C), each held one 4/4 bar.
    /// The most-played chord loop in popular music — a clean first drill for changing on the beat.
    static let gMajorPop = ChordProgression(changes: [
        ChordChange(.gMajor, beats: 4),
        ChordChange(.dMajor, beats: 4),
        ChordChange(.eMinor, beats: 4),
        ChordChange(.cMajor, beats: 4)
    ], keyRoot: 7, keyIsMinor: false)  // G major → I V vi IV
}
