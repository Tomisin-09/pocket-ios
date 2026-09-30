import XCTest
@testable import Pocket

/// The glow moves the way the note was played (ADR 0234 D5).
final class HaloMotionTests: XCTestCase {

    private func spot(_ string: Int, _ fret: Int) -> NeckSpot { NeckSpot(string: string, fret: fret) }
    private func note(_ string: Int, _ fret: Int, bend: Int = 0, vibrato: Bool = false,
                      leadIn: LeadIn? = nil) -> FrettedNote {
        FrettedNote(string: string, fret: fret, bend: bend, vibrato: vibrato, leadIn: leadIn)
    }

    func testAPickedNotePops() {
        XCTAssertEqual(HaloMotion.motions(into: 0, of: [.fretted(string: 2, fret: 5)]), [.pop(spot(2, 5))])
    }

    func testABendGlidesToWhereItLandsAndStopsAtTheLastFret() {
        let labels: [PieceLabel?] = [.fretted([note(1, 8, bend: 2)], into: nil),
                                     .fretted([note(1, 21, bend: 3)], into: nil)]
        XCTAssertEqual(HaloMotion.motions(into: 0, of: labels), [.bend(from: spot(1, 8), to: spot(1, 10))])
        XCTAssertEqual(HaloMotion.motions(into: 1, of: labels, maxFret: 22),
                       [.bend(from: spot(1, 21), to: spot(1, 22))])
    }

    func testVibratoShakes() {
        XCTAssertEqual(HaloMotion.motions(into: 0, of: [.fretted([note(2, 7, vibrato: true)], into: nil)]),
                       [.vibrato(spot(2, 7))])
    }

    func testAJoinFromTheTapBeforeStartsWhereThatNoteWas() {
        let labels: [PieceLabel?] = [.fretted(string: 2, fret: 5), .fretted([note(2, 7)], into: .legato),
                                     .fretted([note(2, 5)], into: .legato), .fretted([note(2, 9)], into: .slide)]
        XCTAssertEqual(HaloMotion.motions(into: 1, of: labels), [.legato(from: spot(2, 5), to: spot(2, 7))],
                       "a hammer-on")
        XCTAssertEqual(HaloMotion.motions(into: 2, of: labels), [.legato(from: spot(2, 7), to: spot(2, 5))],
                       "a pull-off")
        XCTAssertEqual(HaloMotion.motions(into: 3, of: labels), [.slide(from: spot(2, 5), to: spot(2, 9))])
    }

    func testHowItWasReachedComesBeforeABend() {
        let labels: [PieceLabel?] = [.fretted(string: 1, fret: 5), .fretted([note(1, 7, bend: 2)], into: .slide)]
        XCTAssertEqual(HaloMotion.motions(into: 1, of: labels), [.slide(from: spot(1, 5), to: spot(1, 7))])
    }

    func testAJoinThatNoLongerFitsIsAPlainNote() {
        // The note before moved to another string: the stored join is stale, and nothing draws it.
        let labels: [PieceLabel?] = [.fretted(string: 3, fret: 5), .fretted([note(2, 7)], into: .legato)]
        XCTAssertEqual(HaloMotion.motions(into: 1, of: labels), [.pop(spot(2, 7))])
    }

    func testALeadInStartsInsideTheNote() {
        let grace = note(2, 13, leadIn: LeadIn(from: .fret(11), join: .legato))
        let slidIn = note(2, 13, leadIn: LeadIn(from: .below, join: .slide))
        let fromAbove = note(2, 13, leadIn: LeadIn(from: .above, join: .slide))
        XCTAssertEqual(HaloMotion.motions(into: 0, of: [.fretted([grace], into: nil)]),
                       [.legato(from: spot(2, 11), to: spot(2, 13))])
        XCTAssertEqual(HaloMotion.motions(into: 0, of: [.fretted([slidIn], into: nil)]),
                       [.slideIn(to: spot(2, 13), fromBelow: true)])
        XCTAssertEqual(HaloMotion.motions(into: 0, of: [.fretted([fromAbove], into: nil)]),
                       [.slideIn(to: spot(2, 13), fromBelow: false)])
    }

    func testAShapeGlowsOnEveryStringAndNothingElseGlows() {
        let doubleStop = [note(2, 7), note(1, 8)]
        let labels: [PieceLabel?] = [.fretted(doubleStop, into: nil), .pitchClass(3), nil]
        XCTAssertEqual(HaloMotion.motions(into: 0, of: labels), [.pop(spot(2, 7)), .pop(spot(1, 8))])
        XCTAssertTrue(HaloMotion.motions(into: 1, of: labels).isEmpty, "named by ear: nowhere on the neck")
        XCTAssertTrue(HaloMotion.motions(into: 2, of: labels).isEmpty, "unnamed")
        XCTAssertTrue(HaloMotion.motions(into: 9, of: labels).isEmpty)
    }

    func testTheGlowEndsOnTheNoteOrWhereTheBendLands() {
        XCTAssertEqual(HaloMotion.bend(from: spot(1, 8), to: spot(1, 10)).end, spot(1, 10))
        XCTAssertEqual(HaloMotion.legato(from: spot(2, 5), to: spot(2, 7)).end, spot(2, 7))
        XCTAssertEqual(HaloMotion.vibrato(spot(2, 7)).end, spot(2, 7))
    }
}
