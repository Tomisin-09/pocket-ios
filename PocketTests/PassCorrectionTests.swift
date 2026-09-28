import XCTest
@testable import Pocket

/// Correcting the count while naming (ADR 0231): the stretch *Missed a note?* plays, where a tapped-in note
/// lands, a tap taken out, the selection after, the joins a correction breaks, and when Undo is offered.
final class PassCorrectionTests: XCTestCase {

    private typealias Tap = PieceTranscription.Tap

    private func tap(_ seconds: TimeInterval, fret: Int? = nil, into: Join? = nil) -> Tap {
        Tap(seconds: seconds, label: fret.map { .fretted([FrettedNote(string: 2, fret: $0)], into: into) })
    }

    private func join(_ tap: Tap) -> Join? {
        guard case .fretted(_, let into) = tap.label else { return nil }
        return into
    }

    // MARK: - The stretch

    func testTheStretchRunsFromTheTapBeforeToTheTapAfter() throws {
        let seconds: [TimeInterval] = [10, 10.5, 11, 11.5]
        let stretch = try XCTUnwrap(PassCorrection.stretch(around: 1, in: seconds, region: 9...13))
        XCTAssertEqual(stretch.from, 10)
        XCTAssertEqual(stretch.to, 11)
    }

    func testAtTheEndsTheStretchReachesOutButNotPastTheRegion() throws {
        let seconds: [TimeInterval] = [10, 10.5, 11]
        let first = try XCTUnwrap(PassCorrection.stretch(around: 0, in: seconds, region: 9.2...13))
        XCTAssertEqual(first.from, 9.2, "reaches back to the region's start, not a full edgeReach")
        XCTAssertEqual(first.to, 10.5)
        let last = try XCTUnwrap(PassCorrection.stretch(around: 2, in: seconds, region: 9...20))
        XCTAssertEqual(last.from, 10.5)
        XCTAssertEqual(last.to, 11 + PassCorrection.edgeReach, "a full edgeReach where the region allows it")
        let lone = try XCTUnwrap(PassCorrection.stretch(around: 0, in: [10], region: nil))
        XCTAssertEqual(lone.from, 10 - PassCorrection.edgeReach)
        XCTAssertEqual(lone.to, 10 + PassCorrection.edgeReach)
    }

    func testARegionThatNoLongerHoldsThePieceIsIgnored() throws {
        // A saved piece whose loop was since moved to start after its first tap.
        let stretch = try XCTUnwrap(PassCorrection.stretch(around: 0, in: [10, 11], region: 10.5...12))
        XCTAssertEqual(stretch.from, 10 - PassCorrection.edgeReach, "never a stretch that starts after its note")
        XCTAssertNil(PassCorrection.stretch(around: 2, in: [10, 11], region: nil))
    }

    func testTheStretchIsSaidInNotes() {
        XCTAssertEqual(PassCorrection.stretchWords(around: 11, count: 30, noun: "note"),
                       "Plays from note 11 to note 13.")
        XCTAssertEqual(PassCorrection.stretchWords(around: 0, count: 30, noun: "note"),
                       "Plays from just before note 1 to note 2.")
        XCTAssertEqual(PassCorrection.stretchWords(around: 29, count: 30, noun: "chord"),
                       "Plays from chord 29 to just after chord 30.")
    }

    // MARK: - Adding and taking out

    func testANoteTappedInLandsInOrderUnnamed() {
        let taps = [tap(10, fret: 5), tap(11, fret: 7)]
        let between = PassCorrection.adding(10.4, to: taps)
        XCTAssertEqual(between.index, 1)
        XCTAssertEqual(between.taps.map(\.seconds), [10, 10.4, 11])
        XCTAssertEqual(between.taps.map(\.label), [taps[0].label, nil, taps[1].label], "the others keep their names")
        XCTAssertEqual(PassCorrection.adding(9, to: taps).index, 0, "before the first")
        XCTAssertEqual(PassCorrection.adding(12, to: taps).index, 2, "after the last")
        XCTAssertEqual(PassCorrection.adding(11, to: taps).index, 2, "after a tap at the same second")
    }

    func testATapTakenOutTakesItsNameAndNeverTheLastNote() {
        let taps = [tap(10, fret: 5), tap(10.5, fret: 6), tap(11, fret: 7)]
        XCTAssertEqual(PassCorrection.removing(at: 1, from: taps), [taps[0], taps[2]])
        XCTAssertNil(PassCorrection.removing(at: 0, from: [tap(10)]), "a pass keeps one note")
        XCTAssertNil(PassCorrection.removing(at: 3, from: taps))
    }

    func testAfterTakingOneOutTheNextIsSelectedOrTheNewLast() {
        XCTAssertEqual(PassCorrection.selection(afterRemoving: 1, count: 3), 1, "the one that took its place")
        XCTAssertEqual(PassCorrection.selection(afterRemoving: 2, count: 3), 1, "the new last")
        XCTAssertEqual(PassCorrection.selection(afterRemoving: 0, count: 2), 0)
    }

    // MARK: - Joins

    func testANoteAddedBeforeAJoinBreaksIt() {
        // G5 hammered on to G7; a missed note tapped in between leaves G7 nothing named to join from.
        let taps = [tap(10, fret: 5), tap(11, fret: 7, into: .legato)]
        let added = PassCorrection.tidied(PassCorrection.adding(10.5, to: taps).taps)
        XCTAssertNil(join(added[2]), "the join into G7 goes")
        XCTAssertEqual(added[2].label?.frettedNotes, taps[1].label?.frettedNotes, "the note stays")
    }

    func testAJoinStaysWhenTheTapBeforeStillFits() {
        // G5, a stray tap, G7 hammered on from the stray. Taken out, G5 is before G7, and still fits.
        let taps = [tap(10, fret: 5), tap(10.5, fret: 6), tap(11, fret: 7, into: .legato)]
        let removed = PassCorrection.tidied(PassCorrection.removing(at: 1, from: taps) ?? [])
        XCTAssertEqual(join(removed[1]), .legato, "G5 to G7 is still a hammer-on")
    }

    // MARK: - Undo

    func testUndoIsOfferedOnlyWhileNothingHasChangedSince() {
        let before = [tap(10), tap(11)]
        let after = [tap(10)]
        let undo = PassCorrection.Undo(before: before, after: after, selected: 1, said: "Took note 2 out.")
        XCTAssertTrue(undo.isCurrent(for: after))
        XCTAssertFalse(undo.isCurrent(for: [tap(10, fret: 5)]), "a name given since retires it")
    }
}
