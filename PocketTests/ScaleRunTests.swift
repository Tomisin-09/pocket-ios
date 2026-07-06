import XCTest
@testable import Pocket

/// The **scale library generator** (ADR 0065 build 2, Slice 2): verifies the fret-window box
/// generator produces correct, ascending, N-octave runs for every scale, position and octave count —
/// the safety net that lets scales be *generated* from a formula rather than hand-drawn. All pure,
/// SwiftUI-free (T5).
final class ScaleRunTests: XCTestCase {

    /// Open-string MIDI notes, standard tuning, by our string index (0 = high e … 5 = low E).
    private let openMidi = [64, 59, 55, 50, 45, 40]
    private func midi(_ note: FretNote) -> Int { openMidi[note.string] + note.fret }

    // MARK: - Generator correctness (the whole point)

    func testEveryBoxIsInScaleAscendingAndFitsOneHand() {
        for scale in GuitarScale.allCases {
            for position in 1...scale.positionCount {
                for octaves in 1...2 {
                    let run = ScaleRun(scale: scale, rootPitchClass: 9,
                                       position: position, octaves: octaves, roundTrip: false)
                    let notes = run.ascendingNotes
                    let context = "\(scale) pos \(position) oct \(octaves)"
                    XCTAssertFalse(notes.isEmpty, "\(context) produced no notes")

                    let allowed = scale.pitchClasses(root: 9)
                    var previous = Int.min
                    for note in notes {
                        XCTAssertTrue(allowed.contains(GuitarScale.pitchClass(string: note.string,
                                                                             fret: note.fret)),
                                      "\(context): \(note) not in scale")
                        XCTAssertGreaterThan(midi(note), previous, "\(context) should ascend strictly")
                        XCTAssertGreaterThanOrEqual(note.fret, 0, "\(context) fell behind the nut")
                        previous = midi(note)
                    }
                    // Every note is the tonic or an interval above it, and at least one tonic is present.
                    XCTAssertTrue(notes.contains { GuitarScale.pitchClass(string: $0.string,
                                                                          fret: $0.fret) == 9 },
                                  "\(context) should contain the tonic")
                    // A single hand position: the fretted span stays tight (a blues box adds one for ♭5).
                    let frets = notes.map(\.fret)
                    let fretSpan = (frets.max() ?? 0) - (frets.min() ?? 0)
                    XCTAssertLessThanOrEqual(fretSpan, 7, "\(context) fret span too wide")
                    if octaves == 1 {
                        let span = midi(notes[notes.count - 1]) - midi(notes[0])
                        XCTAssertLessThanOrEqual(span, 12, "\(context) one-octave run overshot")
                    }
                }
            }
        }
    }

    /// Locks the flagship shape: A minor pentatonic, position 1 is the CAGED E-shape box (the
    /// relative-C major box filtered to the pentatonic), sitting at frets 7–10.
    func testMinorPentatonicPositionOneIsTheEShapeBox() {
        let run = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9,
                           position: 1, octaves: 2, roundTrip: false)
        XCTAssertEqual(run.ascendingNotes, [
            FretNote(string: 5, fret: 8), FretNote(string: 5, fret: 10),
            FretNote(string: 4, fret: 7), FretNote(string: 4, fret: 10),
            FretNote(string: 3, fret: 7), FretNote(string: 3, fret: 10),
            FretNote(string: 2, fret: 7), FretNote(string: 2, fret: 9),
            FretNote(string: 1, fret: 8), FretNote(string: 1, fret: 10),
            FretNote(string: 0, fret: 8), FretNote(string: 0, fret: 10)
        ])
    }

    /// Regression lock for the D-shape fix: A minor pentatonic, position 2 is the classic box-3
    /// shape, so the fifth (E) must land on the **G string** (string 2, fret 9), never the D string.
    func testMinorPentatonicPositionTwoPutsTheFifthOnTheGString() {
        let run = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9,
                           position: 2, octaves: 2, roundTrip: false)
        XCTAssertEqual(run.ascendingNotes, [
            FretNote(string: 5, fret: 10), FretNote(string: 5, fret: 12),
            FretNote(string: 4, fret: 10), FretNote(string: 4, fret: 12),
            FretNote(string: 3, fret: 10), FretNote(string: 3, fret: 12),
            FretNote(string: 2, fret: 9), FretNote(string: 2, fret: 12),
            FretNote(string: 1, fret: 10), FretNote(string: 1, fret: 13),
            FretNote(string: 0, fret: 10), FretNote(string: 0, fret: 12)
        ])
        // The E on the D string (the old bug) must be gone.
        XCTAssertFalse(run.ascendingNotes.contains { $0.string == 3
            && GuitarScale.pitchClass(string: $0.string, fret: $0.fret) == 4 },
            "the fifth must not sit on the D string")
    }

    /// The classic "box 1 at the 5th fret" A-minor-pentatonic shape lives at CAGED position 5 (the
    /// G-shape of the relative C major) — proof the five boxes cover the shapes players know.
    func testMinorPentatonicPositionFiveIsTheClassicFifthFretBox() {
        let run = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9,
                           position: 5, octaves: 2, roundTrip: false)
        XCTAssertEqual(run.ascendingNotes, [
            FretNote(string: 5, fret: 5), FretNote(string: 5, fret: 8),
            FretNote(string: 4, fret: 5), FretNote(string: 4, fret: 7),
            FretNote(string: 3, fret: 5), FretNote(string: 3, fret: 7),
            FretNote(string: 2, fret: 5), FretNote(string: 2, fret: 7),
            FretNote(string: 1, fret: 5), FretNote(string: 1, fret: 8),
            FretNote(string: 0, fret: 5), FretNote(string: 0, fret: 8)
        ])
    }

    /// Locks the E-shape major-scale box: A major, position 1, two octaves — the full CAGED box the
    /// reference sheet shows (△7 R △2 on the outer strings), not a flat count.
    func testMajorPositionOneIsTheEShapeBox() {
        let run = ScaleRun(scale: .major, rootPitchClass: 9,
                           position: 1, octaves: 2, roundTrip: false)
        XCTAssertEqual(run.ascendingNotes, [
            FretNote(string: 5, fret: 4), FretNote(string: 5, fret: 5), FretNote(string: 5, fret: 7),
            FretNote(string: 4, fret: 4), FretNote(string: 4, fret: 5), FretNote(string: 4, fret: 7),
            FretNote(string: 3, fret: 4), FretNote(string: 3, fret: 6), FretNote(string: 3, fret: 7),
            FretNote(string: 2, fret: 4), FretNote(string: 2, fret: 6), FretNote(string: 2, fret: 7),
            FretNote(string: 1, fret: 5), FretNote(string: 1, fret: 7),
            FretNote(string: 0, fret: 4), FretNote(string: 0, fret: 5), FretNote(string: 0, fret: 7)
        ])
    }

    // MARK: - Scale metadata

    func testEveryScaleOffersFiveCagedPositions() {
        for scale in GuitarScale.allCases {
            XCTAssertEqual(scale.positionCount, 5, "\(scale) should offer five CAGED positions")
        }
    }

    // MARK: - CAGED shape letters (ADR 0065 fretboard polish)

    func testShapeLetterMatchesCAGEDOrderEDCAG() {
        let expected = ["E", "D", "C", "A", "G"]
        for position in 1...5 {
            let run = ScaleRun(scale: .major, rootPitchClass: 9, position: position)
            XCTAssertEqual(run.shapeLetter, expected[position - 1], "position \(position)")
        }
    }

    // MARK: - Clamping

    func testPositionOctaveAndRootClampIntoRange() {
        XCTAssertEqual(ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, position: 99).position, 5)
        XCTAssertEqual(ScaleRun(scale: .minorPentatonic, rootPitchClass: 9, position: 0).position, 1)
        XCTAssertEqual(ScaleRun(scale: .major, rootPitchClass: 9, octaves: 5).octaves, 2)
        XCTAssertEqual(ScaleRun(scale: .major, rootPitchClass: 9, octaves: 0).octaves, 1)
        XCTAssertEqual(ScaleRun(scale: .blues, rootPitchClass: -3).rootPitchClass, 9)   // wraps to A
    }

    // MARK: - Round trip

    func testRoundTripMirrorsWithoutDoublingPeakOrSeam() {
        let run = ScaleRun(scale: .minorPentatonic, rootPitchClass: 9,
                           position: 1, octaves: 2, roundTrip: true)
        let ascentCount = run.ascendingNotes.count
        XCTAssertEqual(run.sequence.count, 2 * ascentCount - 2)
        for pair in zip(run.sequence, run.sequence.dropFirst()) {
            XCTAssertNotEqual(pair.0, pair.1, "no note should repeat back-to-back")
        }
    }

    // MARK: - Naming

    func testTitleReadsRootThenScale() {
        XCTAssertEqual(ScaleRun.aMinorPentatonic.rootName, "A")
        XCTAssertEqual(ScaleRun.aMinorPentatonic.title, "A Minor Pentatonic")
        XCTAssertEqual(ScaleRun.aMinorPentatonic.position, 1)
        XCTAssertEqual(ScaleRun.aMinorPentatonic.octaves, 2)
    }

    // MARK: - Codable + forward-compat

    func testScaleRunRoundTripsThroughCodable() throws {
        let original = ScaleRun(scale: .blues, rootPitchClass: 3,
                                position: 4, octaves: 1, roundTrip: false, notesPerBeat: 3)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ScaleRun.self, from: data), original)
    }

    func testUnknownScaleRawFallsBackToMinorPentatonic() {
        XCTAssertEqual(GuitarScale(storage: "phrygianDominant"), .minorPentatonic)
    }

    func testNewRunCarriesCurrentVersion() {
        XCTAssertEqual(ScaleRun.aMinorPentatonic.version, ScaleRun.currentVersion)
    }

    // MARK: - Root highlighting

    /// The expanded drill carries the tonic so the renderer can light it; a non-tonal drill doesn't,
    /// and the run really does contain root notes to mark.
    func testExpandedRunCarriesRootForHighlighting() {
        let drill = ScaleRun.aMinorPentatonic.expanded()   // A minor pentatonic → root pitch class 9
        XCTAssertEqual(drill.rootPitchClass, 9)
        XCTAssertNil(FretboardDrill.spiderWalk.rootPitchClass)
        let roots = drill.notes.compactMap { $0 }
            .filter { GuitarScale.pitchClass(string: $0.string, fret: $0.fret) == 9 }
        XCTAssertGreaterThanOrEqual(roots.count, 2, "a two-octave run should mark at least two tonics")
    }

    // MARK: - FretboardContent .scale case

    func testContentScaleExpandsAndRoundTrips() throws {
        let content = FretboardContent.scale(.aMinorPentatonic)
        XCTAssertEqual(content.drill, ScaleRun.aMinorPentatonic.expanded())
        XCTAssertEqual(content.scaleValue, .aMinorPentatonic)
        XCTAssertNil(content.runValue)
        let data = try JSONEncoder().encode(content)
        XCTAssertEqual(try JSONDecoder().decode(FretboardContent.self, from: data), content)
    }
}
