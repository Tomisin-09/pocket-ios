import XCTest
@testable import Pocket

/// The three before and the three after, on the neck (ADR 0234 D4).
final class NeckNeighboursTests: XCTestCase {

    private func note(_ string: Int, _ fret: Int) -> PieceLabel { .fretted(string: string, fret: fret) }

    func testTiersRunThreeEachWay() {
        XCTAssertEqual(NeckNeighbours.tier(of: 5, active: 5), .current)
        XCTAssertEqual(NeckNeighbours.tier(of: 4, active: 5), .before(1))
        XCTAssertEqual(NeckNeighbours.tier(of: 2, active: 5), .before(3))
        XCTAssertEqual(NeckNeighbours.tier(of: 1, active: 5), .other, "four back is past the reach")
        XCTAssertEqual(NeckNeighbours.tier(of: 6, active: 5), .after(1))
        XCTAssertEqual(NeckNeighbours.tier(of: 8, active: 5), .after(3))
        XCTAssertEqual(NeckNeighbours.tier(of: 9, active: 5), .other)
    }

    func testEachPlacedSpotShowsItsTierAndNumber() {
        let labels: [PieceLabel?] = [note(2, 5), note(2, 7), note(1, 5), nil, note(1, 8), note(3, 7), note(3, 9),
                                     note(0, 3), note(4, 2)]
        let marks = NeckNeighbours.marks(labels, active: 4)
        XCTAssertEqual(marks[NeckSpot(string: 1, fret: 8)], .init(tier: .current, note: 4))
        XCTAssertEqual(marks[NeckSpot(string: 1, fret: 5)], .init(tier: .before(2), note: 2))
        XCTAssertEqual(marks[NeckSpot(string: 2, fret: 7)], .init(tier: .before(3), note: 1))
        XCTAssertEqual(marks[NeckSpot(string: 2, fret: 5)], .init(tier: .other, note: 0))
        XCTAssertEqual(marks[NeckSpot(string: 3, fret: 7)], .init(tier: .after(1), note: 5))
        XCTAssertEqual(marks[NeckSpot(string: 0, fret: 3)], .init(tier: .after(3), note: 7))
        XCTAssertEqual(marks[NeckSpot(string: 4, fret: 2)], .init(tier: .other, note: 8))
        XCTAssertNil(marks[NeckSpot(string: 5, fret: 0)], "an empty spot has no mark")
    }

    func testASharedSpotShowsTheNearestNote() {
        // A lick that comes back to G7: notes 1, 3 and 6 (0-based) all sit there.
        let labels: [PieceLabel?] = [note(2, 5), note(2, 7), note(1, 5), note(2, 7), note(1, 8), note(1, 5),
                                     note(2, 7)]
        XCTAssertEqual(NeckNeighbours.marks(labels, active: 3)[NeckSpot(string: 2, fret: 7)]?.tier, .current,
                       "the note being named beats any neighbour on its spot")
        XCTAssertEqual(NeckNeighbours.marks(labels, active: 5)[NeckSpot(string: 2, fret: 7)],
                       .init(tier: .after(1), note: 6), "one after beats two before")
        XCTAssertEqual(NeckNeighbours.marks(labels, active: 4)[NeckSpot(string: 1, fret: 5)]?.tier, .after(1),
                       "one after beats two before")
        XCTAssertEqual(NeckNeighbours.marks(labels, active: 4)[NeckSpot(string: 2, fret: 7)]?.tier, .before(1))
        let tie: [PieceLabel?] = [note(2, 7), note(1, 8), note(2, 7)]
        XCTAssertEqual(NeckNeighbours.marks(tie, active: 1)[NeckSpot(string: 2, fret: 7)],
                       .init(tier: .before(1), note: 0), "a tie goes to the one before, where the player has been")
    }

    func testAShapeMarksEveryNote() {
        let shape = PieceLabel.fretted([FrettedNote(string: 1, fret: 5), FrettedNote(string: 2, fret: 5)], into: nil)
        let marks = NeckNeighbours.marks([shape, note(0, 7)], active: 1)
        XCTAssertEqual(marks[NeckSpot(string: 1, fret: 5)]?.tier, .before(1))
        XCTAssertEqual(marks[NeckSpot(string: 2, fret: 5)]?.tier, .before(1))
    }

    func testTheSpokenPositionNamesTheNote() {
        let before = NeckNeighbours.Mark(tier: .before(2), note: 9)
        XCTAssertEqual(NameTheNotesSheet.neighbourWords(before, noun: "note"), ", note 10, 2 before")
        XCTAssertEqual(NameTheNotesSheet.neighbourWords(.init(tier: .after(1), note: 12), noun: "note"),
                       ", note 13, 1 after")
        XCTAssertEqual(NameTheNotesSheet.neighbourWords(nil, noun: "note"), "")
    }
}
