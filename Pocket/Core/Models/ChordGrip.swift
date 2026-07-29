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
        case fifth                            // Tier 1 — the power chord (root + 5th, ADR 0106)
        case sus2, sus4, sixth                // Tier 2
        case dom9, maj9, min9                 // Tier 2 — the 9ths (ADR 0101)

        /// The suffix appended to the root note to name the voicing — "F", "Fm7", "Fsus4", "F5".
        var nameSuffix: String {
            switch self {
            case .major: return ""
            case .minor: return "m"
            case .dom7: return "7"
            case .min7: return "m7"
            case .maj7: return "maj7"
            case .fifth: return "5"
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
            case .fifth: return "Power chord"
            case .sus2: return "Sus2"
            case .sus4: return "Sus4"
            case .sixth: return "Sixth"
            case .dom9: return "Dominant 9"
            case .maj9: return "Major 9"
            case .min9: return "Minor 9"
            }
        }
    }

    /// The string a grip anchors its root on (M2). Raw value indexes the shared high-e-first string
    /// order (0 = high e … 5 = low E). The two barre families root on low E / A; the triad shapes
    /// (ADR 0109) root on any string, since an inversion moves the root off the lowest string of the set.
    enum RootString: Int {
        case eRoot = 5      // low E — the E-shape barre family
        case aRoot = 4      // A string — the A-shape barre family + A-D-G triads
        case dRoot = 3      // D string — D-G-B / A-D-G triads
        case gRoot = 2      // G string — G-B-e / D-G-B / A-D-G triads
        case bRoot = 1      // B string — G-B-e / D-G-B triad inversions
        case eHighRoot = 0  // high e — G-B-e triad inversions
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
    /// Which chord tone is in the bass: `0` root position, `1` first inversion (3rd in the bass), `2`
    /// second inversion (5th in the bass). `0` for every barre/open grip (default); the triad shapes
    /// (ADR 0109) set it so a chip can label "1st inv" / "2nd inv". Doesn't affect the generated voicing.
    var inversion: Int = 0

    /// Player-facing inversion tag for a triad chip — "root" / "1st inv" / "2nd inv".
    var inversionName: String {
        switch inversion {
        case 1: return "1st inv"
        case 2: return "2nd inv"
        default: return "root"
        }
    }
}

// MARK: - Placement (M2/M7 — pure geometry, unit-tested)

extension ChordGrip {
    /// Slide the grip so its root sounds `rootPitchClass`, returning the concrete voicing. The
    /// root-string fret is the lowest fret (0–11) that puts `rootPitchClass` on that string; every
    /// offset is added to it (muted strings stay muted). The result's **name derives from its own
    /// content** — the requested root note + the grip's quality suffix (M2) — so a slid shape
    /// auto-names ("G", "B♭7") with no naming table.
    /// - Parameter spelling: how the generated name spells its root (ADR 0123). A movable grip is placed
    ///   at a bare root with no key around it, so this is the user's accidental preference; the default
    ///   keeps the property tests and the browse pictures deterministic.
    func voicing(rootPitchClass: Int, spelling: NoteSpelling = .default) -> ChordVoicing {
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
        let name = spelling.name(pitchClass: rootPitchClass) + quality.nameSuffix
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

    // A-shape family — root on the A string, **low E muted**, high e **sounding**: the standard
    // 5-string A-D-G-B-e barre. The four Tier-1 triads/7ths and maj7 all put the high e on the *root
    // fret* (`offsets[0] = 0`), where it sounds the **5th** — the top note of every printed A-shape
    // chart. This reverses the original 4-string form (2026-07-13 review, "barring under the high e is
    // awkward and only doubles a tone already sounding"): on device the missing top string made the
    // shapes read wrong against every chart a player has seen, and the barre already covers that fret
    // (ADR 0122). `aShapeMinor` placed at fret 2 (B) is the full 5-string Bm barre — which is why
    // `ChordVoicing.bMinorBarre` gained its high e in step with this change (M5).
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

    // Power chords (ADR 0106) — root + 5th + octave root, no 3rd, so neither major nor minor. The two
    // standard three-string movable shapes: the E-shape roots on the low E (5th on A, octave on D) and
    // sounds those three strings only; the A-shape roots on the A (5th on D, octave on G) and mutes the
    // low E like its A-shape kin. Both derive their name straight from the root — "E5", "A5" — with no
    // 3rd to colour, so the reverse-namer's ≥3-note rule never sees them; the grip names them itself.
    static let eShapeFifth = ChordGrip(name: "E-shape", rootString: .eRoot,
                                       offsets: [nil, nil, nil, 2, 2, 0], quality: .fifth)
    static let aShapeFifth = ChordGrip(name: "A-shape", rootString: .aRoot,
                                       offsets: [nil, nil, 2, 2, 0, nil], quality: .fifth)

    /// Tier 1 (ADR 0084 M3, extended by ADR 0106): triads + 7ths + power chords on the two CAGED root
    /// strings — the curated **default** movable set. Generated, not tabled (M1): the whole vocabulary is
    /// these twelve grips × a root note.
    static let tier1: [ChordGrip] = [
        .eShapeMajor, .eShapeMinor, .eShapeDom7, .eShapeMin7, .eShapeMaj7, .eShapeFifth,
        .aShapeMajor, .aShapeMinor, .aShapeDom7, .aShapeMin7, .aShapeMaj7, .aShapeFifth
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

// MARK: - Triad shapes (ADR 0109 — major/minor on three string sets, all three inversions)

extension ChordGrip {
    // Small three-string triads — root, 3rd, 5th on one adjacent string group, no doublings. `name` is
    // the **string set**; `inversion` says which tone is in the bass. Offsets are relative to the root
    // fret (high-e first), and `rootString` is whichever string carries the root *in that inversion*
    // (offset 0 there). Upper string sets put chord tones above the root, so many offsets are negative —
    // the octave-bump in `voicing()` keeps a low root playable (the shape climbs a register rather than
    // falling off the nut). Minor lowers the 3rd a fret from major on whichever string holds it. All
    // auto-name plain "C" / "Cm" (M2) — an inversion is the same chord, a different voicing.

    // G-B-e set (strings G·B·e).
    static let triadGBEMajor = ChordGrip(name: "G-B-e", rootString: .gRoot,
                                         offsets: [-2, 0, 0, nil, nil, nil], quality: .major)
    static let triadGBEMinor = ChordGrip(name: "G-B-e", rootString: .gRoot,
                                         offsets: [-2, -1, 0, nil, nil, nil], quality: .minor)
    static let triadGBEMajor1 = ChordGrip(name: "G-B-e", rootString: .eHighRoot,
                                          offsets: [0, 0, 1, nil, nil, nil], quality: .major, inversion: 1)
    static let triadGBEMinor1 = ChordGrip(name: "G-B-e", rootString: .eHighRoot,
                                          offsets: [0, 0, 0, nil, nil, nil], quality: .minor, inversion: 1)
    static let triadGBEMajor2 = ChordGrip(name: "G-B-e", rootString: .bRoot,
                                          offsets: [-1, 0, -1, nil, nil, nil], quality: .major, inversion: 2)
    static let triadGBEMinor2 = ChordGrip(name: "G-B-e", rootString: .bRoot,
                                          offsets: [-2, 0, -1, nil, nil, nil], quality: .minor, inversion: 2)

    // D-G-B set (strings D·G·B).
    static let triadDGBMajor = ChordGrip(name: "D-G-B", rootString: .dRoot,
                                         offsets: [nil, -2, -1, 0, nil, nil], quality: .major)
    static let triadDGBMinor = ChordGrip(name: "D-G-B", rootString: .dRoot,
                                         offsets: [nil, -2, -2, 0, nil, nil], quality: .minor)
    static let triadDGBMajor1 = ChordGrip(name: "D-G-B", rootString: .bRoot,
                                          offsets: [nil, 0, -1, 1, nil, nil], quality: .major, inversion: 1)
    static let triadDGBMinor1 = ChordGrip(name: "D-G-B", rootString: .bRoot,
                                          offsets: [nil, 0, -1, 0, nil, nil], quality: .minor, inversion: 1)
    static let triadDGBMajor2 = ChordGrip(name: "D-G-B", rootString: .gRoot,
                                          offsets: [nil, 0, 0, 0, nil, nil], quality: .major, inversion: 2)
    static let triadDGBMinor2 = ChordGrip(name: "D-G-B", rootString: .gRoot,
                                          offsets: [nil, -1, 0, 0, nil, nil], quality: .minor, inversion: 2)

    // A-D-G set (strings A·D·G).
    static let triadADGMajor = ChordGrip(name: "A-D-G", rootString: .aRoot,
                                         offsets: [nil, nil, -3, -1, 0, nil], quality: .major)
    static let triadADGMinor = ChordGrip(name: "A-D-G", rootString: .aRoot,
                                         offsets: [nil, nil, -3, -2, 0, nil], quality: .minor)
    static let triadADGMajor1 = ChordGrip(name: "A-D-G", rootString: .gRoot,
                                          offsets: [nil, nil, 0, 0, 2, nil], quality: .major, inversion: 1)
    static let triadADGMinor1 = ChordGrip(name: "A-D-G", rootString: .gRoot,
                                          offsets: [nil, nil, 0, 0, 1, nil], quality: .minor, inversion: 1)
    static let triadADGMajor2 = ChordGrip(name: "A-D-G", rootString: .dRoot,
                                          offsets: [nil, nil, -1, 0, 0, nil], quality: .major, inversion: 2)
    static let triadADGMinor2 = ChordGrip(name: "A-D-G", rootString: .dRoot,
                                          offsets: [nil, nil, -2, 0, 0, nil], quality: .minor, inversion: 2)

    /// The curated triad set (ADR 0109) — major + minor on the three upper string sets, in **all three
    /// inversions** (root · 1st · 2nd) = 18 shapes. Generated, not tabled (M1). Ordered **set → quality →
    /// inversion** so the 3-column Insert grid lays each quality's three inversions out on **one row**
    /// (row 1 = G-B-e major root/1st/2nd, row 2 = G-B-e minor root/1st/2nd, …).
    static let triads: [ChordGrip] = [
        triadGBEMajor, triadGBEMajor1, triadGBEMajor2, triadGBEMinor, triadGBEMinor1, triadGBEMinor2,
        triadDGBMajor, triadDGBMajor1, triadDGBMajor2, triadDGBMinor, triadDGBMinor1, triadDGBMinor2,
        triadADGMajor, triadADGMajor1, triadADGMajor2, triadADGMinor, triadADGMinor1, triadADGMinor2
    ]
}

// MARK: - Browse picture (ADR 0103 — the chord picker's Insert grid)

extension ChordGrip {
    /// A representative voicing for *browsing* a movable shape in the picker's Insert grid (ADR 0103):
    /// the grip barred at **fret 5**, a clean mid-neck picture of the shape. The chip is deliberately
    /// root-agnostic — it names the quality + family, not this note — because the player chooses the real
    /// root on tap (`voicing(rootPitchClass:)`). Fret 5 is `openRoot + 5`, so an E-shape draws at A and an
    /// A-shape at D, both a full five-string window below the nut region.
    var browseVoicing: ChordVoicing {
        let openRoot = GuitarScale.pitchClass(string: rootString.rawValue, fret: 0)
        return voicing(rootPitchClass: (openRoot + 5) % 12)
    }
}
