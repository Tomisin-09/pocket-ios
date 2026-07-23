import XCTest
@testable import Pocket

/// The **scale sequence axis** (ADR 0108): the pure `SequencePattern` permutation, and its integration
/// into `ScaleRun` — sequencing reorders the *played* run without disturbing the ascending box the
/// labels/anchors read. All SwiftUI-free (the repo's pure-logic rule).
final class ScaleSequenceTests: XCTestCase {

    // MARK: - SequencePattern index math

    func testStraightIsIdentity() {
        XCTAssertEqual(SequencePattern.straight.indices(count: 5), [0, 1, 2, 3, 4])
        XCTAssertEqual(SequencePattern.straight.indices(count: 0), [])
    }

    func testThirdsPairEachNoteWithTwoAbove() {
        // 1 3 2 4 3 5 … — each note then the scale tone two steps up, dropping the pair off the top.
        XCTAssertEqual(SequencePattern.thirds.indices(count: 5), [0, 2, 1, 3, 2, 4, 3, 4])
    }

    func testFourthsPairEachNoteWithThreeAbove() {
        XCTAssertEqual(SequencePattern.fourths.indices(count: 7),
                       [0, 3, 1, 4, 2, 5, 3, 6, 4, 5, 6])
    }

    func testGroupsOfThreeRollAWindow() {
        XCTAssertEqual(SequencePattern.groupsOfThree.indices(count: 5),
                       [0, 1, 2, 1, 2, 3, 2, 3, 4, 3, 4, 4])
    }

    func testEveryPatternCoversEveryNote() {
        // No pattern may drop a note — every original index must appear at least once (so the whole
        // scale is still practised), and none may index out of range.
        for pattern in SequencePattern.allCases {
            for count in [1, 5, 7, 12] {
                let indices = pattern.indices(count: count)
                XCTAssertEqual(Set(indices), Set(0..<count), "\(pattern) count \(count) must cover all notes")
                XCTAssertTrue(indices.allSatisfy { $0 >= 0 && $0 < count }, "\(pattern) out of range")
            }
        }
    }

    func testApplyReordersNotesAndGroupsInStep() {
        let notes = ["a", "b", "c", "d", "e"]
        let groups = [0, 0, 1, 1, 2]
        let (seqNotes, seqGroups) = SequencePattern.thirds.apply(to: notes, groups: groups)
        // Same permutation applied to both arrays keeps them index-aligned.
        XCTAssertEqual(seqNotes, [0, 2, 1, 3, 2, 4, 3, 4].map { notes[$0] })
        XCTAssertEqual(seqGroups, [0, 2, 1, 3, 2, 4, 3, 4].map { groups[$0] })
    }

    func testStraightApplyIsANoOp() {
        let notes = [1, 2, 3]
        let (seqNotes, seqGroups) = SequencePattern.straight.apply(to: notes, groups: nil)
        XCTAssertEqual(seqNotes, notes)
        XCTAssertNil(seqGroups)
    }

    // MARK: - ScaleRun integration

    func testDefaultSequenceIsStraight() {
        XCTAssertEqual(ScaleRun.aMinorPentatonic.sequencePattern, .straight)
    }

    func testSequencingLeavesTheAscendingBoxUnchanged() {
        // Sequencing reorders only the *played* run — the ascending box (which the labels/anchors read)
        // must be byte-identical to the straight run's, so nothing about the box shifts.
        let straight = ScaleRun(scale: .major, rootPitchClass: 7, position: 1, octaves: 2)
        let thirds = ScaleRun(scale: .major, rootPitchClass: 7, position: 1, octaves: 2, sequence: .thirds)
        XCTAssertEqual(thirds.ascendingNotes, straight.ascendingNotes)
        XCTAssertEqual(thirds.rootAnchor, straight.rootAnchor)
    }

    func testSequencingChangesThePlayedRun() {
        let straight = ScaleRun(scale: .major, rootPitchClass: 7, position: 1,
                                octaves: 2, roundTrip: false)
        let thirds = ScaleRun(scale: .major, rootPitchClass: 7, position: 1,
                              octaves: 2, roundTrip: false, sequence: .thirds)
        XCTAssertNotEqual(thirds.sequence, straight.sequence, "the played order differs")
        // The thirds run is a permutation-with-repeats of the box's notes, so every straight note still
        // appears — no note leaves the scale (FretNote is Equatable, not Hashable, so check membership).
        XCTAssertTrue(straight.sequence.allSatisfy { thirds.sequence.contains($0) },
                      "every box note still appears in the thirds run")
        XCTAssertGreaterThan(thirds.sequence.count, straight.sequence.count, "thirds emits pairs")
    }

    func testSequenceRawRoundTripsThroughCodable() throws {
        let original = ScaleRun(scale: .major, rootPitchClass: 0, position: 2,
                                octaves: 2, sequence: .groupsOfThree)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScaleRun.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.sequencePattern, .groupsOfThree)
    }

    func testBlobWithoutSequenceDecodesToStraight() throws {
        // A ScaleRun encoded before this axis existed has no `sequenceRaw` key — it must decode to the
        // straight pattern (the additive, no-migration guarantee).
        let json = """
        {"version":1,"scaleRaw":"major","rootPitchClass":7,"position":1,"octaves":2,\
        "roundTrip":true,"notesPerBeat":2,"layoutRaw":"box"}
        """
        let decoded = try JSONDecoder().decode(ScaleRun.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.sequencePattern, .straight)
    }

    func testCuratedThirdsPresetIsSequenced() {
        XCTAssertEqual(ScaleRun.gMajorInThirds.sequencePattern, .thirds)
    }
}
