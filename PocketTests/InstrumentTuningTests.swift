import XCTest
@testable import Pocket

/// The pure instrument + tuning catalog (ADR 0115): guitar and bass, their curated tunings, note-name
/// spelling (shared with the fretboard via `GuitarScale.noteName`), and guided-mode nearest-string.
final class InstrumentTuningTests: XCTestCase {

    // MARK: catalog

    func testInstrumentRawValuesStable() {
        // Raw values are the persisted `@AppStorage` keys — a rename would silently reset choices.
        XCTAssertEqual(Instrument.allCases.map(\.rawValue), ["guitar", "bass"])
        XCTAssertEqual(Instrument.default, .guitar)
    }

    func testStandardIsFirstForEveryInstrument() {
        for instrument in Instrument.allCases {
            XCTAssertEqual(instrument.tunings.first?.name, "Standard",
                           "\(instrument) must list Standard first (reset target)")
            XCTAssertEqual(instrument.standardTuning, instrument.tunings[0])
            XCTAssertFalse(instrument.displayName.isEmpty)
        }
    }

    func testGuitarHasSixStringsAndBassFour() {
        for tuning in Instrument.guitar.tunings {
            XCTAssertEqual(tuning.stringCount, 6, "guitar tuning \(tuning.name)")
        }
        for tuning in Instrument.bass.tunings {
            XCTAssertEqual(tuning.stringCount, 4, "bass tuning \(tuning.name)")
        }
    }

    // MARK: engine boundary (ADR 0116 — the one lowest-first → highest-first crossing)

    func testEngineOpenMidiIsGuitarConstantByteForByte() {
        // The golden test: guitar Standard's engine order must equal the engine's long-standing
        // hardcoded constant (CAGEDShape.openMidi / ChordVoicing.openMidi), proving the reversal
        // adapter changes nothing for guitar. If this drifts, every stored guitar drill re-renders.
        XCTAssertEqual(Instrument.guitar.standardTuning.engineOpenMidi, [64, 59, 55, 50, 45, 40])
        XCTAssertEqual(Instrument.guitar.standardTuning.engineOpenMidi, CAGEDShape.openMidi)
        XCTAssertEqual(Instrument.guitar.standardTuning.engineOpenMidi, ChordVoicing.openMidi)
    }

    func testEngineOpenMidiReversesBassLowestFirstToHighestFirst() {
        // Bass Standard is E1 A1 D2 G2 lowest-first (28 33 38 43); the engine wants highest-first.
        XCTAssertEqual(Instrument.bass.standardTuning.midiNotes, [28, 33, 38, 43])
        XCTAssertEqual(Instrument.bass.standardTuning.engineOpenMidi, [43, 38, 33, 28])
    }

    func testEngineOpenMidiIsExactReversalPreservingCount() {
        for instrument in Instrument.allCases {
            for tuning in instrument.tunings {
                XCTAssertEqual(tuning.engineOpenMidi, tuning.midiNotes.reversed())
                XCTAssertEqual(tuning.engineOpenMidi.count, tuning.stringCount)
            }
        }
    }

    // MARK: spelling

    /// Open-string names are **always sharp** and deliberately outside the accidental preference
    /// (ADR 0123): Open D's third string is F♯, the raised third of D major, for everyone.
    func testCompactLabelsMatchExpectedSpelling() {
        let guitar = Dictionary(uniqueKeysWithValues: Instrument.guitar.tunings.map { ($0.name, $0.compactLabel) })
        XCTAssertEqual(guitar["Standard"], "EADGBE")
        XCTAssertEqual(guitar["Drop D"], "DADGBE")
        XCTAssertEqual(guitar["Open G"], "DGDGBD")
        XCTAssertEqual(guitar["Open D"], "DADF♯AD")
        XCTAssertEqual(guitar["Open E"], "EBEG♯BE")
        XCTAssertEqual(guitar["DADGAD"], "DADGAD")
        XCTAssertEqual(guitar["Drop C"], "CGCFAD")

        let bass = Dictionary(uniqueKeysWithValues: Instrument.bass.tunings.map { ($0.name, $0.compactLabel) })
        XCTAssertEqual(bass["Standard"], "EADG")
        XCTAssertEqual(bass["Drop D"], "DADG")
    }

    // MARK: guided-mode nearest string

    func testNearestStringPicksTheRightOpenString() {
        let standard = Instrument.guitar.standardTuning         // E2 A2 D3 G3 B3 E4 → 40 45 50 55 59 64
        XCTAssertEqual(standard.nearestStringIndex(toMidi: 40), 0)   // dead-on low E
        XCTAssertEqual(standard.nearestStringIndex(toMidi: 64), 5)   // dead-on high E
        XCTAssertEqual(standard.nearestStringIndex(toMidi: 43), 1)   // closest to A2 (45), not E2 (40)
        XCTAssertEqual(standard.nearestStringIndex(toMidi: 56), 3)   // closest to G3 (55), one semitone
    }

    func testNearestStringUsesAbsolutePitchNotClass() throws {
        // DADGAD has three D's (D2 D3 D4). A detected D3 must map to the middle D string, not the low
        // one — proof the match is by absolute MIDI distance, not pitch class.
        let dadgad = try XCTUnwrap(Instrument.guitar.tunings.first { $0.name == "DADGAD" })  // 38 45 50 55 57 62
        XCTAssertEqual(dadgad.nearestStringIndex(toMidi: 50), 2)   // D3 → 3rd string (index 2)
        XCTAssertEqual(dadgad.nearestStringIndex(toMidi: 38), 0)   // D2 → 6th string (index 0)
        XCTAssertEqual(dadgad.nearestStringIndex(toMidi: 62), 5)   // D4 → 1st string (index 5)
    }

    func testNearestStringTieResolvesToLowerString() {
        // Exactly between two strings 4 semitones apart → the lower (smaller index) wins.
        let tuning = Tuning(name: "tie", midiNotes: [40, 44])
        XCTAssertEqual(tuning.nearestStringIndex(toMidi: 42), 0)
    }

    // MARK: name resolution (settings ↔ tuning)

    func testTuningNamedResolvesAKnownTuning() {
        XCTAssertEqual(Instrument.guitar.tuning(named: "Drop D").compactLabel, "DADGBE")
        XCTAssertEqual(Instrument.bass.tuning(named: "Drop D").compactLabel, "DADG")
    }

    func testTuningNamedFallsBackToStandard() {
        // A guitar-only tuning name left in @AppStorage after switching to bass must land on the bass
        // Standard, never leak a guitar tuning onto bass (ADR 0115).
        XCTAssertEqual(Instrument.bass.tuning(named: "Open G"), Instrument.bass.standardTuning)
        XCTAssertEqual(Instrument.guitar.tuning(named: "nonsense"), Instrument.guitar.standardTuning)
    }

    // MARK: mode (guided / chromatic)

    func testTunerModeRawValuesStable() {
        // Raw values persist as the @AppStorage mode key — a rename silently resets it.
        XCTAssertEqual(TunerMode.allCases.map(\.rawValue), ["guided", "chromatic"])
        XCTAssertEqual(TunerMode.default, .guided)
        for mode in TunerMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
            XCTAssertFalse(mode.blurb.isEmpty)
        }
    }
}
