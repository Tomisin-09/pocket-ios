import XCTest
@testable import Pocket

/// Higher, same or lower (ADR 0301): what each lets through, what the note before is, what dims, which
/// arrows survive a change to the pass, and the words.
final class PitchDirectionTests: XCTestCase {

    /// Standard tuning, highest-first: e B G D A E.
    private let standard = [64, 59, 55, 50, 45, 40]

    private func note(_ string: Int, _ fret: Int) -> PieceLabel { .fretted(string: string, fret: fret) }

    private func tap(_ seconds: TimeInterval, _ label: PieceLabel? = nil) -> PieceTranscription.Tap {
        PieceTranscription.Tap(seconds: seconds, label: label)
    }

    // MARK: - What fits

    func testEachDirectionLetsThroughItsSide() {
        XCTAssertTrue(PitchDirection.higher.fits(63, from: 62))
        XCTAssertFalse(PitchDirection.higher.fits(62, from: 62), "the same pitch isn't higher")
        XCTAssertFalse(PitchDirection.higher.fits(61, from: 62))
        XCTAssertTrue(PitchDirection.same.fits(62, from: 62))
        XCTAssertFalse(PitchDirection.same.fits(74, from: 62), "an octave up is another pitch")
        XCTAssertTrue(PitchDirection.lower.fits(61, from: 62))
        XCTAssertFalse(PitchDirection.lower.fits(62, from: 62))
    }

    func testThreeDirectionsInButtonOrder() {
        XCTAssertEqual(PitchDirection.allCases, [.higher, .same, .lower])
        XCTAssertEqual(PitchDirection.allCases.map(\.title), ["Higher", "Same", "Lower"])
        XCTAssertEqual(PitchDirection.allCases.map(\.symbol), ["arrow.up", "equal", "arrow.down"])
    }

    // MARK: - The note before

    func testTheNoteBeforeIsReadByWhatItIs() {
        let labels: [PieceLabel?] = [
            note(2, 7), nil, .muted(strings: [3]), .muted,
            .fretted([FrettedNote(string: 2, fret: 7), FrettedNote(string: 1, fret: 8)], into: nil),
            .pitchClass(2), .chord(root: 9, suffix: "m"), note(1, 8)
        ]
        func before(_ index: Int) -> PitchDirection.Before {
            PitchDirection.before(index, in: labels, openMidi: standard)
        }
        XCTAssertEqual(before(0), .nothing, "note 1 has nothing before it")
        XCTAssertEqual(before(1), .note(NeckSpot(string: 2, fret: 7), midi: 62), "G7 is D above middle C")
        XCTAssertEqual(before(2), .unplaced)
        XCTAssertEqual(before(3), .muted, "a ✕ on the neck")
        XCTAssertEqual(before(4), .muted, "Muted by ear")
        XCTAssertEqual(before(5), .severalNotes)
        XCTAssertEqual(before(6), .byEar)
        XCTAssertEqual(before(7), .byEar, "a chord named by ear")
        XCTAssertEqual(before(9), .nothing, "past the end")
    }

    func testTheNoteBeforeIsComparedWhereItLands() {
        let held = PieceLabel.fretted([FrettedNote(string: 2, fret: 7, bend: 2)], into: nil)
        let released = PieceLabel.fretted([FrettedNote(string: 2, fret: 7, bend: 2, releases: true)], into: nil)
        let spot = NeckSpot(string: 2, fret: 7)
        XCTAssertEqual(PitchDirection.before(1, in: [held, nil], openMidi: standard), .note(spot, midi: 64),
                       "a held bend counts at its bent pitch (ADR 0288 D2)")
        XCTAssertEqual(PitchDirection.before(1, in: [released, nil], openMidi: standard), .note(spot, midi: 62),
                       "a released bend counts at its own fret")
    }

    func testAStringPastTheTuningReadsAsNotPlaced() {
        XCTAssertEqual(PitchDirection.before(1, in: [note(6, 3), nil], openMidi: standard), .unplaced)
    }

    // MARK: - What dims

    func testHigherDimsEverythingAtOrBelowTheNoteBefore() throws {
        // Note 1 is G7 (D, MIDI 62); note 2 is being named.
        let narrowing = try XCTUnwrap(NeckNarrowing.make(.higher, at: 1, in: [note(2, 7), nil], openMidi: standard))
        XCTAssertTrue(narrowing.dims(string: 2, fret: 6), "G6 is lower")
        XCTAssertFalse(narrowing.dims(string: 2, fret: 8), "G8 is higher")
        XCTAssertTrue(narrowing.dims(string: 1, fret: 3), "B3 is the same D, so not higher")
        XCTAssertFalse(narrowing.dims(string: 0, fret: 0), "the open e is higher")
        XCTAssertTrue(narrowing.dims(string: 5, fret: 12), "the low E's twelfth is lower")
        XCTAssertFalse(narrowing.dims(string: 2, fret: 7), "the note compared with stays bright")
        XCTAssertFalse(narrowing.dims(string: 9, fret: 2), "a string the tuning hasn't got dims nothing")
    }

    func testSameLeavesOnlyThatPitch() throws {
        let narrowing = try XCTUnwrap(NeckNarrowing.make(.same, at: 1, in: [note(2, 7), nil], openMidi: standard))
        var bright: [NeckSpot] = []
        for string in standard.indices {
            for fret in 0...PieceLabel.maxFret where !narrowing.dims(string: string, fret: fret) {
                bright.append(NeckSpot(string: string, fret: fret))
            }
        }
        // D (62) on B3, G7, D12, A17 and E22.
        XCTAssertEqual(Set(bright), [NeckSpot(string: 1, fret: 3), NeckSpot(string: 2, fret: 7),
                                     NeckSpot(string: 3, fret: 12), NeckSpot(string: 4, fret: 17),
                                     NeckSpot(string: 5, fret: 22)])
    }

    func testLowerDimsEverythingAtOrAbove() throws {
        let narrowing = try XCTUnwrap(NeckNarrowing.make(.lower, at: 1, in: [note(2, 7), nil], openMidi: standard))
        XCTAssertFalse(narrowing.dims(string: 2, fret: 5))
        XCTAssertTrue(narrowing.dims(string: 1, fret: 3), "the same D isn't lower")
        XCTAssertTrue(narrowing.dims(string: 0, fret: 0))
    }

    func testTheNotesOwnAnswerStaysBright() throws {
        // Note 2 is already on G5, lower than G7, and the arrow says higher.
        let narrowing = try XCTUnwrap(NeckNarrowing.make(.higher, at: 1, in: [note(2, 7), note(2, 5)],
                                                         openMidi: standard))
        XCTAssertFalse(narrowing.dims(string: 2, fret: 5), "its own answer is never dimmed")
        XCTAssertTrue(narrowing.dims(string: 2, fret: 4))
    }

    func testEveryCrossDimsUnlessItIsTheNotesOwn() throws {
        let narrowing = try XCTUnwrap(NeckNarrowing.make(.higher, at: 1, in: [note(2, 7), .muted(strings: [4])],
                                                         openMidi: standard))
        XCTAssertTrue(narrowing.dimsMute(string: 0), "a muted note has no pitch")
        XCTAssertFalse(narrowing.dimsMute(string: 4), "the note's own ✕ stays bright")
    }

    func testNothingDimsWithoutAnArrowOrAPitchBefore() {
        XCTAssertNil(NeckNarrowing.make(nil, at: 1, in: [note(2, 7), nil], openMidi: standard), "no arrow")
        XCTAssertNil(NeckNarrowing.make(.higher, at: 0, in: [note(2, 7), nil], openMidi: standard), "note 1")
        XCTAssertNil(NeckNarrowing.make(.higher, at: 1, in: [nil, nil], openMidi: standard),
                     "the note before isn't placed: the arrow waits (D5)")
        XCTAssertNil(NeckNarrowing.make(.higher, at: 1, in: [.muted(strings: [2]), nil], openMidi: standard))
        XCTAssertNil(NeckNarrowing.make(.higher, at: 1, in: [.pitchClass(2), nil], openMidi: standard))
        let shape = PieceLabel.fretted([FrettedNote(string: 2, fret: 7), FrettedNote(string: 1, fret: 8)], into: nil)
        XCTAssertNil(NeckNarrowing.make(.higher, at: 1, in: [shape, nil], openMidi: standard))
    }

    // MARK: - Which arrows survive

    func testAnArrowStaysWhileItsNoteAndTheNoteBeforeStay() {
        let old = [tap(1), tap(2), tap(3)]
        let new = [tap(1, note(2, 7)), tap(2), tap(3)]
        XCTAssertEqual(PitchDirection.kept([2: .higher, 3: .lower], from: old, to: new), [2: .higher, 3: .lower],
                       "placing the note before leaves the arrow, which is when it starts to dim")
    }

    func testAnsweringANoteTakesItsArrowOff() {
        let old = [tap(1, note(2, 7)), tap(2), tap(3)]
        let new = [tap(1, note(2, 7)), tap(2, note(2, 9)), tap(3)]
        XCTAssertEqual(PitchDirection.kept([2: .higher, 3: .lower], from: old, to: new), [3: .lower])
        let byEar = [tap(1, note(2, 7)), tap(2, .pitchClass(4)), tap(3)]
        XCTAssertEqual(PitchDirection.kept([2: .higher], from: old, to: byEar), [:], "named by ear too")
    }

    func testANoteTappedInBeforeAnArrowTakesItOff() {
        let old = [tap(1), tap(2), tap(3)]
        let new = [tap(1), tap(1.5), tap(2), tap(3)]
        XCTAssertEqual(PitchDirection.kept([2: .higher, 3: .lower], from: old, to: new), [3: .lower],
                       "the note it was compared with is no longer the one before it")
    }

    func testANoteTakenOutGoesWithItsArrowAndTheOneAfter() {
        let old = [tap(1), tap(2), tap(3), tap(4)]
        let new = [tap(1), tap(3), tap(4)]
        XCTAssertEqual(PitchDirection.kept([2: .same, 3: .higher, 4: .lower], from: old, to: new), [4: .lower])
    }

    // MARK: - The words (D7)

    func testTheRowSaysWhatItComparesWith() {
        let spot = NeckSpot(string: 2, fret: 7)
        XCTAssertEqual(PitchDirection.rowTitle(at: 0, before: .nothing, noun: "note", spelling: .sharps),
                       "Note 1 has nothing before it")
        XCTAssertEqual(PitchDirection.rowTitle(at: 5, before: .note(spot, midi: 62), noun: "note", spelling: .sharps),
                       "From note 5 · D")
        XCTAssertEqual(PitchDirection.rowTitle(at: 5, before: .note(spot, midi: 63), noun: "note", spelling: .flats),
                       "From note 5 · E♭", "spelled as the neck spells it")
        XCTAssertEqual(PitchDirection.rowTitle(at: 5, before: .unplaced, noun: "note", spelling: .sharps),
                       "From note 5")
    }

    func testTheLineUnderTheNeckSaysWhyItDimsOrDoesnt() {
        let spot = NeckSpot(string: 2, fret: 7)
        func line(_ direction: PitchDirection, _ before: PitchDirection.Before) -> String? {
            direction.caption(at: 5, before: before, noun: "note", spelling: .sharps)
        }
        XCTAssertEqual(line(.higher, .note(spot, midi: 62)),
                       "Higher than note 5 (D). The spots it can’t be are dimmed, and still take a tap.")
        XCTAssertEqual(line(.same, .note(spot, midi: 62)),
                       "The same as note 5 (D). The spots it can’t be are dimmed, and still take a tap.")
        XCTAssertEqual(line(.lower, .unplaced), "Nothing is dimmed until note 5 is placed.")
        XCTAssertEqual(line(.lower, .muted), "Note 5 is muted, so there’s no pitch to compare with.")
        XCTAssertEqual(line(.lower, .severalNotes), "Note 5 is several notes, so there’s no one pitch to compare with.")
        XCTAssertEqual(line(.lower, .byEar), "Note 5 was named by ear, with no octave to compare with.")
        XCTAssertNil(line(.higher, .nothing))
    }

    func testVoiceOverSaysTheDirectionFromTheNote() {
        XCTAssertEqual(PitchDirection.higher.spoken(from: 5, noun: "note"), "Higher than note 5")
        XCTAssertEqual(PitchDirection.same.spoken(from: 5, noun: "note"), "The same as note 5")
        XCTAssertEqual(PitchDirection.lower.spoken(from: 5, noun: "note"), "Lower than note 5")
        XCTAssertEqual(PitchDirection.allCases.map(\.heard), ["heard higher", "heard the same", "heard lower"])
    }
}
