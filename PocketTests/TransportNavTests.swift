import XCTest
@testable import Pocket

final class TransportNavTests: XCTestCase {

    private let order = [1, 2, 3]

    func testPreviousReturnsPriorElement() {
        XCTAssertEqual(TransportNav.previous(before: 2, in: order), 1)
        XCTAssertEqual(TransportNav.previous(before: 3, in: order), 2)
    }

    func testPreviousIsNilAtStart() {
        XCTAssertNil(TransportNav.previous(before: 1, in: order))
    }

    func testNextReturnsFollowingElement() {
        XCTAssertEqual(TransportNav.next(after: 1, in: order), 2)
        XCTAssertEqual(TransportNav.next(after: 2, in: order), 3)
    }

    func testNextIsNilAtEnd() {
        XCTAssertNil(TransportNav.next(after: 3, in: order))
    }

    func testNilCurrentHasNoNeighbours() {
        XCTAssertNil(TransportNav.previous(before: nil, in: order))
        XCTAssertNil(TransportNav.next(after: nil, in: order))
    }

    func testAbsentCurrentHasNoNeighbours() {
        XCTAssertNil(TransportNav.previous(before: 99, in: order))
        XCTAssertNil(TransportNav.next(after: 99, in: order))
    }

    func testSingleElementHasNoNeighbours() {
        XCTAssertNil(TransportNav.previous(before: 1, in: [1]))
        XCTAssertNil(TransportNav.next(after: 1, in: [1]))
    }

    func testEmptyOrderHasNoNeighbours() {
        XCTAssertNil(TransportNav.previous(before: 1, in: []))
        XCTAssertNil(TransportNav.next(after: 1, in: []))
    }
}
