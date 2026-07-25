import XCTest
@testable import Pocket

/// Bass render fixes (ADR 0116 S5): the tuning-aware pitch class the board labels resolve against, and
/// the nut-inclusive display window for boxes rooted on an open string. Pure — the label/root correctness
/// and window framing are the bits that broke silently on the first device pass (a bass open-E root read
/// as "D" in guitar tuning; the open root sat stranded on the nut).
final class FretboardDrillTuningTests: XCTestCase {

    // MARK: - Nut-inclusive display window

    func testDisplayWindowFramesFromTheNutWhenOpenAndFrettedNotesMix() {
        // A bass box rooted on an open string mixes fret 0 with mid-neck notes — the window frames from
        // the nut (fret 1) so the open root reads next to the low frets instead of stranded.
        let box = FretboardDrill(notesPerBeat: 1, notes: [FretNote(string: 3, fret: 0),
                                                          FretNote(string: 3, fret: 3),
                                                          FretNote(string: 3, fret: 7)])
        XCTAssertEqual(box.displayLowestFret, 1)      // not 3 — nut-inclusive
        XCTAssertEqual(box.displayFretSpan, 7)        // frets 1…7 inclusive
    }

    func testAllFrettedBoxWithNoOpensStillFramesFromTheLowestFret() {
        // Guitar mid-neck boxes (no open notes) are unchanged — framed at the lowest fretted note.
        let box = FretboardDrill(notesPerBeat: 1, notes: [FretNote(string: 3, fret: 5),
                                                          FretNote(string: 3, fret: 9)])
        XCTAssertEqual(box.displayLowestFret, 5)
    }

    func testOpenPositionGuitarBoxAlsoFramesFromTheNut() {
        // The anti-cramming framing is instrument-agnostic: an OPEN-position guitar box (no stamped
        // tuning ⇒ guitar) rooted on the open low E frames from the nut just like the bass box, so an
        // open E-minor-pentatonic on guitar never strands its open root (user concern, ADR 0116 S5).
        let openGuitar = FretboardDrill(notesPerBeat: 1, notes: [FretNote(string: 5, fret: 0),
                                                                 FretNote(string: 5, fret: 3),
                                                                 FretNote(string: 4, fret: 2),
                                                                 FretNote(string: 3, fret: 2)])
        XCTAssertNil(openGuitar.openMidi)             // guitar
        XCTAssertEqual(openGuitar.displayLowestFret, 1)   // nut-inclusive, not fret 2
    }

    // MARK: - Tuning-aware pitch class

    func testPitchClassResolvesInGuitarTuningByDefault() {
        // No stamped tuning ⇒ guitar standard, byte-identical to the old GuitarScale.pitchClass path.
        let drill = FretboardDrill(notesPerBeat: 1, notes: [nil])
        for string in 0..<6 {
            for fret in [0, 3, 7] {
                let note = FretNote(string: string, fret: fret)
                XCTAssertEqual(drill.pitchClass(of: note),
                               GuitarScale.pitchClass(string: string, fret: fret))
            }
        }
    }

    func testPitchClassResolvesInBassTuningWhenStamped() {
        // Bass engine tuning is highest-first [G2,D2,A1,E1] = [43,38,33,28]; string 3 is the low E.
        let bass = FretboardDrill(notesPerBeat: 1, notes: [nil],
                                  stringCount: 4, openMidi: Instrument.bass.engineOpenMidi)
        XCTAssertEqual(bass.pitchClass(of: FretNote(string: 3, fret: 0)), 4)   // open low E → E
        XCTAssertEqual(bass.pitchClass(of: FretNote(string: 0, fret: 0)), 7)   // open G string → G
        XCTAssertEqual(bass.pitchClass(of: FretNote(string: 3, fret: 3)), 7)   // low E, fret 3 → G
    }

    func testBassScaleBoxIsStampedAndRootsOnOpenE() {
        // The regression behind the device report: the E-minor-pentatonic bass box must root on the open
        // E, and its labels/root must resolve in bass tuning — not read as "D" via guitar tuning.
        let drill = ScaleRun.eMinorPentatonicBass.expanded(instrument: .bass)
        XCTAssertEqual(drill.openMidi, Instrument.bass.engineOpenMidi)
        XCTAssertEqual(drill.rootPitchClass, 4)   // E
        let firstNote = drill.notes.compactMap { $0 }.first
        XCTAssertEqual(firstNote?.string, 3)      // opens on the low E string
        XCTAssertEqual(firstNote?.fret, 0)        // open
        // Resolved in bass tuning the opening note is the root E; in guitar tuning it would read D (2).
        XCTAssertEqual(firstNote.map { drill.pitchClass(of: $0) }, 4)
        XCTAssertNotEqual(GuitarScale.pitchClass(string: 3, fret: 0), 4)
    }

    func testCustomBassDrillIsRestampedFromTheExerciseInstrumentAtRender() {
        // A .custom drill persists without its transient openMidi; FretboardContent.drill(instrument:)
        // stamps it back so a saved bass custom labels in bass tuning after a reload.
        let custom = FretboardContent.custom(FretboardDrill(notesPerBeat: 1,
                                                            notes: [FretNote(string: 3, fret: 0)],
                                                            stringCount: 4))
        XCTAssertEqual(custom.drill(instrument: .bass).openMidi, Instrument.bass.engineOpenMidi)
        XCTAssertNil(custom.drill(instrument: .guitar).openMidi)   // guitar unchanged
    }
}
