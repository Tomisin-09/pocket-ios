import CoreGraphics
import XCTest
@testable import Pocket

/// The **move cue**'s geometry (`MoveArrow`, 2026-11-21): the arrowhead a walking board draws in the gap
/// between the note just played and the one lit now. It must point the way the hand went (the old line
/// didn't say), sit in the gap between the two dots' edges, and stay off a gap it doesn't fit.
final class MoveArrowTests: XCTestCase {

    private let accuracy: CGFloat = 0.0001

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        ((lhs.x - rhs.x) * (lhs.x - rhs.x) + (lhs.y - rhs.y) * (lhs.y - rhs.y)).squareRoot()
    }

    // MARK: - Direction

    func testAMoveUpTheStringPointsUpTheString() throws {
        let head = try XCTUnwrap(MoveArrow.head(from: CGPoint(x: 0, y: 50), fromRadius: 6,
                                                to: CGPoint(x: 80, y: 50), toRadius: 9))
        // The tip is further along than both barbs, and the barbs sit level with each other.
        XCTAssertGreaterThan(head.tip.x, head.left.x)
        XCTAssertEqual(head.left.x, head.right.x, accuracy: accuracy)
        XCTAssertEqual(head.tip.y, 50, accuracy: accuracy)
    }

    func testTheSameMoveBackDownPointsTheOtherWay() throws {
        // The case the line couldn't tell apart: the same two notes, the other way round.
        let head = try XCTUnwrap(MoveArrow.head(from: CGPoint(x: 80, y: 50), fromRadius: 6,
                                                to: CGPoint(x: 0, y: 50), toRadius: 9))
        XCTAssertLessThan(head.tip.x, head.left.x)
        XCTAssertEqual(head.left.x, head.right.x, accuracy: accuracy)
    }

    func testADiagonalJumpPointsAlongTheJumpWithEvenBarbs() throws {
        let from = CGPoint(x: 10, y: 10), to = CGPoint(x: 70, y: 90)
        let head = try XCTUnwrap(MoveArrow.head(from: from, fromRadius: 6, to: to, toRadius: 9))
        // The tip is on the line between the two notes…
        let cross = (to.x - from.x) * (head.tip.y - from.y) - (to.y - from.y) * (head.tip.x - from.x)
        XCTAssertEqual(cross, 0, accuracy: 0.001)
        // …closer to where the hand went than the barbs are…
        XCTAssertLessThan(distance(head.tip, to), distance(head.left, to))
        XCTAssertLessThan(distance(head.tip, to), distance(head.right, to))
        // …and the two barbs are the same length.
        XCTAssertEqual(distance(head.tip, head.left), distance(head.tip, head.right), accuracy: accuracy)
    }

    // MARK: - Where it sits

    func testItSitsInTheMiddleOfTheGapNotBetweenTheCentres() throws {
        // Dots of different sizes: the lit one is drawn larger. Centres 0 and 100, edges at 6 and 91, so
        // the gap's middle is 48.5, not 50.
        let head = try XCTUnwrap(MoveArrow.head(from: CGPoint(x: 0, y: 0), fromRadius: 6,
                                                to: CGPoint(x: 100, y: 0), toRadius: 9))
        let middle = (head.tip.x + head.left.x) / 2
        XCTAssertEqual(middle, 48.5, accuracy: accuracy)
        XCTAssertEqual(head.tip.x - head.left.x, MoveArrow.depth, accuracy: accuracy)
        XCTAssertEqual(head.left.y - head.right.y, 2 * MoveArrow.halfWidth, accuracy: accuracy)
    }

    // MARK: - When it stays off

    func testItStaysOffAGapItDoesntFit() {
        // A string apart with captions on: dots of 18 and 21 points, 25 points apart, leave under 6.
        XCTAssertNil(MoveArrow.head(from: CGPoint(x: 40, y: 0), fromRadius: 9,
                                    to: CGPoint(x: 40, y: 25), toRadius: 10.5))
    }

    func testItFitsAGapExactlyItsSizeAndNotOneSmaller() {
        let needed = MoveArrow.depth + 2 * MoveArrow.clearance
        XCTAssertNotNil(MoveArrow.head(from: .zero, fromRadius: 6,
                                       to: CGPoint(x: 6 + needed + 9, y: 0), toRadius: 9))
        XCTAssertNil(MoveArrow.head(from: .zero, fromRadius: 6,
                                    to: CGPoint(x: 6 + needed + 9 - 0.5, y: 0), toRadius: 9))
    }

    func testNoMoveDrawsNothing() {
        XCTAssertNil(MoveArrow.head(from: CGPoint(x: 5, y: 5), fromRadius: 6,
                                    to: CGPoint(x: 5, y: 5), toRadius: 9))
    }

    // MARK: - The switch

    func testTheArrowsAreOnUntilThePlayerTurnsThemOff() {
        XCTAssertTrue(AppSettings.fretboardShowsMovesDefault)
    }
}
