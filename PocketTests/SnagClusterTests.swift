import XCTest
@testable import Pocket

/// Turning snags into a tighter loop (ADR 0200). This is the logic that makes a snag worth marking
/// before the Oracle can read one, so the cases that matter most are the ones where it declines: a
/// suggestion that fires on scattered marks moves a loop the player deliberately set.
final class SnagClusterTests: XCTestCase {

    // MARK: it proposes

    func testThreeMarksInOneBarProposeATightLoop() throws {
        let span = try XCTUnwrap(SnagCluster.proposal(snagSeconds: [120.8, 121.2, 121.5],
                                                      loopStart: 118, loopEnd: 124))
        XCTAssertEqual(span.start, 120.55, accuracy: 0.001)   // lowest − pad
        XCTAssertEqual(span.end, 121.75, accuracy: 0.001)     // highest + pad
    }

    func testASingleMarkStillProposesAPlayableLoop() throws {
        // One mark is a point, not a span. The floor-width window around it is exactly the
        // "loop the moment it goes wrong" the tap asked for.
        let span = try XCTUnwrap(SnagCluster.proposal(snagSeconds: [121.0],
                                                      loopStart: 118, loopEnd: 124))
        XCTAssertEqual(span.end - span.start, WaveformGesture.minLoopSeconds, accuracy: 0.001)
        XCTAssertEqual((span.start + span.end) / 2, 121.0, accuracy: 0.001)
    }

    func testTheProposalIsTighterThanTheLoop() throws {
        let span = try XCTUnwrap(SnagCluster.proposal(snagSeconds: [120.8, 121.2],
                                                      loopStart: 118, loopEnd: 124))
        XCTAssertLessThan(span.end - span.start, 6)
    }

    // MARK: it declines — the cases that protect the player's own loop

    func testScatteredMarksProposeNothing() {
        // Marks spread across the loop are a true reading: the trouble is not in one place. The
        // honest answer is silence, not a cluster picked out of noise.
        XCTAssertNil(SnagCluster.proposal(snagSeconds: [118.5, 120.0, 121.5, 123.5],
                                          loopStart: 118, loopEnd: 124))
    }

    func testMarksOutsideTheLoopAreIgnored() {
        // A dense cluster elsewhere in the song must not drag this loop across the song.
        XCTAssertNil(SnagCluster.proposal(snagSeconds: [30.0, 30.2, 30.4],
                                          loopStart: 118, loopEnd: 124))
    }

    func testNoMarksProposeNothing() {
        XCTAssertNil(SnagCluster.proposal(snagSeconds: [], loopStart: 118, loopEnd: 124))
    }

    func testADegenerateLoopProposesNothing() {
        XCTAssertNil(SnagCluster.proposal(snagSeconds: [120], loopStart: 120, loopEnd: 120))
    }

    func testAnAlreadyTightLoopProposesNothing() {
        // The loop is already at the floor and the mark is inside it — there is no tighter loop to
        // offer, and returning the same bounds would be an action that does nothing.
        XCTAssertNil(SnagCluster.proposal(snagSeconds: [120.2],
                                          loopStart: 120, loopEnd: 120.5))
    }

    // MARK: it stays inside the loop the player set

    func testAProposalNearTheLoopStartIsClampedNotShifted() throws {
        // Padding would run off the front of the loop. It clamps to the loop edge and keeps its
        // width, rather than proposing a span that starts before the loop does.
        let span = try XCTUnwrap(SnagCluster.proposal(snagSeconds: [118.05],
                                                      loopStart: 118, loopEnd: 124))
        XCTAssertGreaterThanOrEqual(span.start, 118)
        XCTAssertEqual(span.end - span.start, WaveformGesture.minLoopSeconds, accuracy: 0.001)
    }

    func testAProposalNearTheLoopEndIsClampedNotShifted() throws {
        let span = try XCTUnwrap(SnagCluster.proposal(snagSeconds: [123.95],
                                                      loopStart: 118, loopEnd: 124))
        XCTAssertLessThanOrEqual(span.end, 124)
        XCTAssertEqual(span.end - span.start, WaveformGesture.minLoopSeconds, accuracy: 0.001)
    }

    // MARK: composition with ADR 0199

    func testATypicalProposalWasImpossibleBeforeTheFloorFix() throws {
        // This proposal is ~1.2s. On a four-minute song the old 2%-of-the-song floor was 4.8s, so
        // the loop could not have been expressed at all. One ADR made the span reachable; this one
        // says where it goes.
        let span = try XCTUnwrap(SnagCluster.proposal(snagSeconds: [120.8, 121.5],
                                                      loopStart: 118, loopEnd: 124))
        let width = span.end - span.start
        XCTAssertLessThan(width, 0.02 * 240)
        XCTAssertGreaterThanOrEqual(width, WaveformGesture.minLoopSeconds)
    }
}
