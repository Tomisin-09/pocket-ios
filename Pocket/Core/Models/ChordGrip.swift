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
    /// property test's oracle (M7). Tier 1 (ADR 0084 M3) is the triads + 7ths; Tier 2 adds the
    /// suspensions and sixths.
    enum Quality: String, CaseIterable {
        case major, minor, dom7, min7, maj7   // Tier 1
        case sus2, sus4, sixth                // Tier 2
        case dom9, maj9, min9                 // Tier 2 — the 9ths (ADR 0101)

        /// The suffix appended to the root note to name the voicing — "F", "Fm7", "Fsus4", "F6".
        var nameSuffix: String {
            switch self {
            case .major: return ""
            case .minor: return "m"
            case .dom7: return "7"
            case .min7: return "m7"
            case .maj7: return "maj7"
            case .sus2: return "sus2"
            case .sus4: return "sus4"
            case .sixth: return "6"
            case .dom9: return "9"
            case .maj9: return "maj9"
            case .min9: return "m9"
            }
        }

        /// Player-facing label for the quality menu.
        var displayName: String {
            switch self {
            case .major: return "Major"
            case .minor: return "Minor"
            case .dom7: return "Dominant 7"
            case .min7: return "Minor 7"
            case .maj7: return "Major 7"
            case .sus2: return "Sus2"
            case .sus4: return "Sus4"
            case .sixth: return "Sixth"
            case .dom9: return "Dominant 9"
            case .maj9: return "Major 9"
            case .min9: return "Minor 9"
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
        var rootFret = (((rootPitchClass - openRootPitchClass) % 12) + 12) % 12
        // A grip with a **sub-root offset** — the 9ths, whose 9th (or 3rd) idiomatically sits a fret
        // *below* the root on an inner string (ADR 0101) — can fall off the nut at a low root. Bump the
        // whole shape up an octave so every fret stays playable: the movable idea holds, the voicing
        // just lands higher up the neck (the "jumps an octave" the ADR 0084 note anticipated). Grips
        // with only non-negative offsets never trigger this, so open shapes are unaffected.
        if let minOffset = offsets.compactMap({ $0 }).min(), rootFret + minOffset < 0 {
            rootFret += 12
        }
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
    // Maj7 is the one E-shape that isn't a full barre as actually played (2026-07-13 device review
    // vs. the standard CAGED chart): the six-string barre-plus-stretch is unplayable, so the shape
    // mutes the A and high e and voices the shell (root, maj7, 3, 5) on low E / D / G / B.
    static let eShapeMaj7 = ChordGrip(name: "E-shape", rootString: .eRoot,
                                      offsets: [nil, 0, 1, 1, nil, 0], quality: .maj7)

    // A-shape family — root on the A string, **low E and high e both muted**: the common 4-string
    // A-D-G-B barre (2026-07-13 review), not the 5-string form — barring cleanly under the high e is
    // awkward, and it only doubles a tone already sounding. `aShapeMinor` placed at fret 2 (B)
    // reproduces `ChordVoicing.bMinorBarre` byte-for-byte (M5); both mute the high e.
    static let aShapeMajor = ChordGrip(name: "A-shape", rootString: .aRoot,
                                       offsets: [nil, 2, 2, 2, 0, nil], quality: .major)
    static let aShapeMinor = ChordGrip(name: "A-shape", rootString: .aRoot,
                                       offsets: [nil, 1, 2, 2, 0, nil], quality: .minor)
    static let aShapeDom7 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [nil, 2, 0, 2, 0, nil], quality: .dom7)
    static let aShapeMin7 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [nil, 1, 0, 2, 0, nil], quality: .min7)
    static let aShapeMaj7 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [nil, 2, 1, 2, 0, nil], quality: .maj7)

    /// Tier 1 (ADR 0084 M3): triads + 7ths on the two CAGED root strings — the curated **default**
    /// movable set. Generated, not tabled (M1): the whole vocabulary is these ten grips × a root note.
    static let tier1: [ChordGrip] = [
        .eShapeMajor, .eShapeMinor, .eShapeDom7, .eShapeMin7, .eShapeMaj7,
        .aShapeMajor, .aShapeMinor, .aShapeDom7, .aShapeMin7, .aShapeMaj7
    ]

    // Tier 2 (M3): suspensions + sixths, in guitar-idiomatic voicings. A-shapes mute the high e like
    // their Tier-1 kin. Sus2 is A-shape only (the E-shape sus2 is an awkward stretch nobody plays);
    // conversely **Sixth is E-shape only** — the A-shape 6 voices its defining 6th *on* the high e
    // string, so muting that string (the 4-string A-D-G-B barre) would erase the 6th and leave a plain
    // major. The 6th sits safely on the B string in the E-shape.
    static let aShapeSus2 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [nil, 0, 2, 2, 0, nil], quality: .sus2)
    static let eShapeSus4 = ChordGrip(name: "E-shape", rootString: .eRoot,
                                      offsets: [0, 0, 2, 2, 2, 0], quality: .sus4)
    static let aShapeSus4 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [nil, 3, 2, 2, 0, nil], quality: .sus4)
    static let eShapeSixth = ChordGrip(name: "E-shape", rootString: .eRoot,
                                       offsets: [0, 2, 1, 2, 2, 0], quality: .sixth)

    // Tier 2 — the **9ths** (ADR 0101, reversing the ADR 0084 note that punted these to the placer).
    // The 9th is a 2nd above the root; on an inner string that pitch sits a fret *below* the root fret,
    // so the A-shape 9ths carry sub-root offsets and rely on the octave-bump in `voicing()`. All are
    // drop-5-tolerant guitar-idiomatic forms, verified against the standard chart (and on device for
    // the E-shapes). `dom9`/`min9` sound the high e (a doubled 5th on the iconic barre); `maj9` mutes
    // it for the clean R-3-7-9 shell.
    //
    // A-shape (root on A) — the idiomatic home of the movable 9th. `aShapeDom9` @ C is x-3-2-3-3-3
    // (the funk "9 chord"); `aShapeMaj9` @ C is x-3-2-4-3-x; `aShapeMin9` @ C is x-3-1-3-3-3.
    static let aShapeDom9 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [0, 0, 0, -1, 0, nil], quality: .dom9)
    static let aShapeMaj9 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [nil, 0, 1, -1, 0, nil], quality: .maj9)
    static let aShapeMin9 = ChordGrip(name: "A-shape", rootString: .aRoot,
                                      offsets: [0, 0, 0, -2, 0, nil], quality: .min9)
    // E-shape (root on low E) — barre-derived, so every offset is ≥ 0 (no octave-bump needed).
    // `eShapeDom9` @ F is the 3-1-2-1-3-1 (low→high) F9 barre; the maj9/min9 shells move the 9 onto the
    // high e. The maj9 mutes the A string like its maj7 kin (the full barre is unplayable, ADR 0084).
    static let eShapeDom9 = ChordGrip(name: "E-shape", rootString: .eRoot,
                                      offsets: [2, 0, 1, 0, 2, 0], quality: .dom9)
    static let eShapeMaj9 = ChordGrip(name: "E-shape", rootString: .eRoot,
                                      offsets: [2, 0, 1, 1, nil, 0], quality: .maj9)
    static let eShapeMin9 = ChordGrip(name: "E-shape", rootString: .eRoot,
                                      offsets: [2, 0, 0, 0, 2, 0], quality: .min9)

    /// Tier 2 (M3): suspensions + sixths + 9ths.
    static let tier2: [ChordGrip] = [
        .aShapeSus2, .eShapeSus4, .aShapeSus4, .eShapeSixth,
        .aShapeDom9, .eShapeDom9, .aShapeMaj9, .eShapeMaj9, .aShapeMin9, .eShapeMin9
    ]

    /// The **curated** movable set the authoring sheet offers — Tier 1–2 (ADR 0084 M3). Tier 3
    /// (shells / extensions / altered) lives behind the custom placer, not here.
    static let curated: [ChordGrip] = tier1 + tier2
}
