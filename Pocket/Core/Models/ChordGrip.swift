import Foundation

/// A **movable chord shape** (ADR 0084) — relative geometry that becomes a concrete `ChordVoicing`
/// when slid to a fret. The player thinks in *grips*: an "E-shape" or "A-shape" barre is one
/// fingering slid along the neck to sound a different chord (F, then F♯, then G…). A grip stores that
/// fingering *relative* to its root fret, plus which string carries the root and what quality it
/// sounds; placing it at a root note transposes the offsets to absolute frets and yields the one
/// `ChordVoicing` the renderer already draws (M2/M5).
///
/// Pure and SwiftUI-free (M7). Nothing here is persisted — a grip is an *authoring recipe* whose
/// *output* (`ChordVoicing`) is the only thing that lives on disk (M1: generate, never store a
/// voicing table).
struct ChordGrip: Equatable {

    /// The chord quality a grip sounds. Names the generated voicing (`root` + suffix) and is the
    /// property test's oracle (M7).
    enum Quality: String, CaseIterable {
        case major, minor, dom7, min7, maj7

        /// The suffix appended to the root note to name the voicing — "F", "Fm", "F7", "Fm7", "Fmaj7".
        var nameSuffix: String {
            switch self {
            case .major: return ""
            case .minor: return "m"
            case .dom7: return "7"
            case .min7: return "m7"
            case .maj7: return "maj7"
            }
        }
    }

    /// The string a grip anchors its root on (M2) — the two the CAGED chart uses. Raw value indexes
    /// the shared high-e-first string order (0 = high e … 5 = low E). D-root is left to the placer for
    /// now (ADR 0084 open question).
    enum RootString: Int {
        case eRoot = 5   // low E — the E-shape barre family
        case aRoot = 4   // A string — the A-shape barre family
    }

    /// Player-facing label for the shape family — "E-shape", "A-shape".
    var name: String
    /// Which string carries the root.
    var rootString: RootString
    /// Fret offsets per string **relative to the grip's root fret**, high-e first (index 0 … 5 low E).
    /// `nil` = muted, `0` = on the root fret (a barre sits at `0` across its strings), `n` = n frets
    /// above it. The entry at `rootString` is `0` by construction — the root sits on the root fret.
    var offsets: [Int?]
    /// The quality the shape sounds.
    var quality: Quality
}

// MARK: - Placement (M2/M7 — pure geometry, unit-tested)

extension ChordGrip {
    /// Slide the grip so its root sounds `rootPitchClass`, returning the concrete voicing. The
    /// root-string fret is the lowest fret (0–11) that puts `rootPitchClass` on that string; every
    /// offset is added to it (muted strings stay muted). The result's **name derives from its own
    /// content** — the requested root note + the grip's quality suffix (M2) — so a slid shape
    /// auto-names ("G", "B♭7") with no naming table.
    func voicing(rootPitchClass: Int) -> ChordVoicing {
        let openRootPitchClass = GuitarScale.pitchClass(string: rootString.rawValue, fret: 0)
        let rootFret = (((rootPitchClass - openRootPitchClass) % 12) + 12) % 12
        let frets = offsets.map { offset -> Int? in
            guard let offset else { return nil }
            return rootFret + offset
        }
        let name = GuitarScale.noteName(forPitchClass: rootPitchClass) + quality.nameSuffix
        return ChordVoicing(name, frets: frets)
    }
}

// MARK: - Tier 1 grips (ADR 0084 M3 — triads + 7ths, the curated default)

extension ChordGrip {
    // E-shape family — root on the low E string. `eShapeMajor` placed at fret 1 (F) reproduces
    // `ChordVoicing.fBarre` byte-for-byte (M5).
    static let eShapeMajor = ChordGrip(name: "E-shape", rootString: .eRoot,
                                       offsets: [0, 0, 1, 2, 2, 0], quality: .major)
    static let eShapeMinor = ChordGrip(name: "E-shape", rootString: .eRoot,
                                       offsets: [0, 0, 0, 2, 2, 0], quality: .minor)
    static let eShapeDom7 = ChordGrip(name: "E-shape", rootString: .eRoot,
                                      offsets: [0, 0, 1, 0, 2, 0], quality: .dom7)
    static let eShapeMin7 = ChordGrip(name: "E-shape", rootString: .eRoot,
                                      offsets: [0, 0, 0, 0, 2, 0], quality: .min7)
    static let eShapeMaj7 = ChordGrip(name: "E-shape", rootString: .eRoot,
                                      offsets: [0, 0, 1, 1, 2, 0], quality: .maj7)

    // A-shape family — root on the A string, low E muted. `aShapeMinor` placed at fret 2 (B)
    // reproduces `ChordVoicing.bMinorBarre` byte-for-byte (M5).
    static let aShapeMajor = ChordGrip(name: "A-shape", rootString: .aRoot,
                                       offsets: [0, 2, 2, 2, 0, nil], quality: .major)
    static let aShapeMinor = ChordGrip(name: "A-shape", rootString: .aRoot,
                                       offsets: [0, 1, 2, 2, 0, nil], quality: .minor)
    static let aShapeDom7 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [0, 2, 0, 2, 0, nil], quality: .dom7)
    static let aShapeMin7 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [0, 1, 0, 2, 0, nil], quality: .min7)
    static let aShapeMaj7 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [0, 2, 1, 2, 0, nil], quality: .maj7)

    /// Tier 1 (ADR 0084 M3): triads + 7ths on the two CAGED root strings — the curated **default**
    /// movable set. Generated, not tabled (M1): the whole vocabulary is these ten grips × a root note.
    static let tier1: [ChordGrip] = [
        .eShapeMajor, .eShapeMinor, .eShapeDom7, .eShapeMin7, .eShapeMaj7,
        .aShapeMajor, .aShapeMinor, .aShapeDom7, .aShapeMin7, .aShapeMaj7
    ]
}
