import XCTest
@testable import Pocket

/// The pure **chord-naming engine** (ADR 0093): reverse lookup from sounded pitch classes to ranked
/// chord names. Root-position triads and sevenths, inversion (slash) naming, symmetric chords with
/// several true roots, sus2/sus4 equivalence, sharp enharmonic spelling, honest no-match, ambiguity
/// ranking, and the `ChordVoicing` adapter. All SwiftUI-free (ADR 0093 N1).
final class ChordNamerTests: XCTestCase {

    // MARK: - Root-position triads

    func testMajorTriad() {
        // {C, E, G} with C in the bass ⇒ "C".
        XCTAssertEqual(ChordNamer.candidates(pitchClasses: [0, 4, 7], bassPitchClass: 0).first?.displayName, "C")
    }

    func testMinorTriad() {
        // {A, C, E} with A in the bass ⇒ "Am".
        XCTAssertEqual(ChordNamer.candidates(pitchClasses: [9, 0, 4], bassPitchClass: 9).first?.displayName, "Am")
    }

    func testDiminishedTriad() {
        // {B, D, F} ⇒ "Bdim".
        XCTAssertEqual(ChordNamer.candidates(pitchClasses: [11, 2, 5], bassPitchClass: 11).first?.displayName, "Bdim")
    }

    func testAugmentedTriadIsSymmetricWithThreeRoots() {
        // {C, E, G#} — an augmented triad has three equally-valid roots.
        let candidates = ChordNamer.candidates(pitchClasses: [0, 4, 8], bassPitchClass: 0)
        XCTAssertEqual(candidates.count, 3)
        XCTAssertEqual(candidates.first?.displayName, "Caug")   // C in the bass ⇒ C is the root
    }

    // MARK: - Sevenths

    func testDominantSeventh() {
        // {E, G#, B, D} ⇒ "E7".
        XCTAssertEqual(ChordNamer.candidates(pitchClasses: [4, 8, 11, 2], bassPitchClass: 4).first?.displayName, "E7")
    }

    func testMajorSeventh() {
        // {C, E, G, B} ⇒ "Cmaj7".
        let best = ChordNamer.candidates(pitchClasses: [0, 4, 7, 11], bassPitchClass: 0).first
        XCTAssertEqual(best?.displayName, "Cmaj7")
    }

    func testMinorSeventh() {
        // {A, C, E, G} with A in the bass ⇒ "Am7".
        XCTAssertEqual(ChordNamer.candidates(pitchClasses: [9, 0, 4, 7], bassPitchClass: 9).first?.displayName, "Am7")
    }

    func testHalfDiminished() {
        // {B, D, F, A} ⇒ "Bm7♭5".
        let best = ChordNamer.candidates(pitchClasses: [11, 2, 5, 9], bassPitchClass: 11).first
        XCTAssertEqual(best?.displayName, "Bm7♭5")
    }

    // MARK: - Inversions (slash names, ADR 0093 N5)

    func testFirstInversionGetsSlashName() {
        // {C, E, G} but with E in the bass ⇒ "C/E", not "C".
        let best = ChordNamer.candidates(pitchClasses: [0, 4, 7], bassPitchClass: 4).first
        XCTAssertEqual(best?.displayName, "C/E")
        XCTAssertTrue(best?.isInversion == true)
        XCTAssertEqual(best?.name, "C")   // the root-position reading is still available
    }

    func testSecondInversionTriadIsTagged() {
        // {F♯, B, D♯} with F♯ (the 5th of B) in the bass ⇒ B/F♯, a 2nd-inversion B major.
        let best = ChordNamer.candidates(pitchClasses: [6, 11, 3], bassPitchClass: 6).first
        XCTAssertEqual(best?.displayName, "B/F#")
        XCTAssertEqual(best?.name, "B")            // the plain triad name the panel also offers
        XCTAssertEqual(best?.inversion, 2)
        XCTAssertEqual(best?.inversionLabel, "2nd inv")
    }

    func testFirstInversionIsTagged() {
        // {E, G, C} with E (the 3rd of C) in the bass ⇒ C/E, a 1st inversion.
        let best = ChordNamer.candidates(pitchClasses: [0, 4, 7], bassPitchClass: 4).first
        XCTAssertEqual(best?.inversion, 1)
        XCTAssertEqual(best?.inversionLabel, "1st inv")
    }

    func testRootPositionHasNoInversionTag() {
        let best = ChordNamer.candidates(pitchClasses: [0, 4, 7], bassPitchClass: 0).first
        XCTAssertEqual(best?.inversion, 0)
        XCTAssertNil(best?.inversionLabel)
    }

    func testDiminishedSeventhReturnsAllFourRoots() {
        // {C, E♭, G♭, A} is fully symmetric — four true dim7 readings; C in the bass names it first.
        let candidates = ChordNamer.candidates(pitchClasses: [0, 3, 6, 9], bassPitchClass: 0)
        XCTAssertEqual(candidates.count, 4)
        XCTAssertEqual(candidates.first?.displayName, "Cdim7")
        XCTAssertFalse(candidates.first?.isInversion == true)   // root == bass
    }

    // MARK: - Enharmonic equivalence & spelling (N6)

    func testSus2AndSus4AreTheSameNotes() {
        // {C, D, G}: Csus2 (root C) and Gsus4 (root G) both spell it. Bass picks the root position.
        let asC = ChordNamer.candidates(pitchClasses: [0, 2, 7], bassPitchClass: 0)
        XCTAssertEqual(asC.first?.displayName, "Csus2")
        let asG = ChordNamer.candidates(pitchClasses: [0, 2, 7], bassPitchClass: 7)
        XCTAssertEqual(asG.first?.displayName, "Gsus4")
        XCTAssertEqual(Set(asC.map(\.name)), ["Csus2", "Gsus4"])   // both readings returned either way
    }

    func testRootsAreSharpSpelled() {
        // {F♯, A♯, C♯} ⇒ "F♯" spelled with a sharp (no key ⇒ sharp table, agrees with the board).
        XCTAssertEqual(ChordNamer.candidates(pitchClasses: [6, 10, 1], bassPitchClass: 6).first?.displayName, "F#")
    }

    // MARK: - Honest fallbacks

    func testChromaticClusterHasNoName() {
        XCTAssertTrue(ChordNamer.candidates(pitchClasses: [0, 1, 2], bassPitchClass: 0).isEmpty)
    }

    func testTwoNoteFifthNamesAPowerChord() {
        // A root + 5th is a named chord — "C5" (ADR 0106). The lower note is the root/bass.
        XCTAssertEqual(ChordNamer.candidates(pitchClasses: [0, 7], bassPitchClass: 0).first?.displayName, "C5")
        // Read from the 5th in the bass, the same two notes are that power chord inverted (G in bass → C5/G).
        XCTAssertEqual(ChordNamer.candidates(pitchClasses: [0, 7], bassPitchClass: 7).first?.displayName, "C5/G")
    }

    func testTwoNoteNonFifthIsStillNotAChord() {
        // Every other dyad remains a bare interval, not a chord — only the perfect 5th names.
        XCTAssertTrue(ChordNamer.candidates(pitchClasses: [0, 4], bassPitchClass: 0).isEmpty)   // major 3rd
        XCTAssertTrue(ChordNamer.candidates(pitchClasses: [0, 6], bassPitchClass: 0).isEmpty)   // tritone
        XCTAssertTrue(ChordNamer.candidates(pitchClasses: [0], bassPitchClass: 0).isEmpty)      // single note
    }

    // MARK: - Ambiguity ranking (C6 vs Am7 — the same four notes)

    func testSharedSetRanksByBassThenCommonness() {
        // {C, E, G, A} is both C6 and Am7. The bass decides the root position.
        let overC = ChordNamer.candidates(pitchClasses: [0, 4, 7, 9], bassPitchClass: 0)
        XCTAssertEqual(overC.first?.displayName, "C6")
        let overA = ChordNamer.candidates(pitchClasses: [0, 4, 7, 9], bassPitchClass: 9)
        XCTAssertEqual(overA.first?.displayName, "Am7")
        // With no bass, the more common quality (m7) wins over the 6th.
        let noBass = ChordNamer.candidates(pitchClasses: [0, 4, 7, 9])
        XCTAssertEqual(noBass.first?.name, "Am7")
    }

    // MARK: - ChordVoicing adapter (N2)

    func testAdapterNamesLibraryVoicings() {
        XCTAssertEqual(ChordNamer.bestName(for: .cMajor), "C")
        XCTAssertEqual(ChordNamer.bestName(for: .aMinor), "Am")
        XCTAssertEqual(ChordNamer.bestName(for: .eDom7), "E7")
        XCTAssertEqual(ChordNamer.bestName(for: .cMajor7), "Cmaj7")
        XCTAssertEqual(ChordNamer.bestName(for: .fBarre), "F")
    }

    func testAdapterDetectsInversionFromLowestString() {
        // A C major triad voiced with E as the lowest sounding string reads as an inversion.
        let cOverE = ChordVoicing("x", frets: [0, 1, 0, 2, nil, nil])   // e:E B:C G:G D:E → bass E
        XCTAssertEqual(ChordNamer.bestName(for: cOverE), "C/E")
    }

    func testEmptyVoicingHasNoName() {
        XCTAssertNil(ChordNamer.bestName(for: ChordVoicing("x", frets: Array(repeating: nil, count: 6))))
    }
}
