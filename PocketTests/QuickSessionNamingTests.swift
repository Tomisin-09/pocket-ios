import XCTest
@testable import Pocket

/// Default naming for generated Quick sessions (V2 planner Slice 1) — pure numbering, so the
/// de-duplication is exercised directly. Date formatting is locale-aware and asserted loosely.
final class QuickSessionNamingTests: XCTestCase {

    func testUniquedReturnsBaseWhenFree() {
        XCTAssertEqual(QuickSessionNaming.uniqued("8 Jul Quick Session", existing: []), "8 Jul Quick Session")
        XCTAssertEqual(QuickSessionNaming.uniqued("8 Jul Quick Session", existing: ["Something else"]),
                       "8 Jul Quick Session")
    }

    func testUniquedNumbersFromTwoAndSkipsTakenSuffixes() {
        let base = "8 Jul Quick Session"
        XCTAssertEqual(QuickSessionNaming.uniqued(base, existing: [base]), "8 Jul Quick Session 2")
        XCTAssertEqual(QuickSessionNaming.uniqued(base, existing: [base, "\(base) 2"]),
                       "8 Jul Quick Session 3")
        // A gap in the middle is filled by the first free suffix.
        XCTAssertEqual(QuickSessionNaming.uniqued(base, existing: [base, "\(base) 3"]),
                       "8 Jul Quick Session 2")
    }

    func testUniquedTrimsBlankBase() {
        XCTAssertEqual(QuickSessionNaming.uniqued("  8 Jul Quick Session  ", existing: []),
                       "8 Jul Quick Session")
    }

    func testDefaultNameIsDatedAndDeDuplicated() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = QuickSessionNaming.defaultName(existing: [], date: date)
        XCTAssertTrue(first.hasSuffix("Quick Session"), "default name ends with the label: \(first)")
        let second = QuickSessionNaming.defaultName(existing: [first], date: date)
        XCTAssertEqual(second, "\(first) 2")
    }
}
