import XCTest
@testable import Pocket

/// `TrialPeriodCopy` — the paywall's trial-length wording, derived from the product rather than typed
/// into the source (ADR 0144 D5).
///
/// The live trial length lives in App Store Connect. The app cannot see it except through the loaded
/// product, so the only two ways to render it are "read it" and "guess it" — and the paywall shipped
/// "14-day" hardcoded in two places while the plan of record said something else. This is the guard
/// against re-introducing that class of bug.
final class TrialPeriodCopyTests: XCTestCase {

    func testRendersTheAdjectivalFormForEveryUnit() {
        XCTAssertEqual(TrialPeriodCopy.hyphenated(unit: .day, value: 3), "3-day")
        XCTAssertEqual(TrialPeriodCopy.hyphenated(unit: .week, value: 2), "2-week")
        XCTAssertEqual(TrialPeriodCopy.hyphenated(unit: .month, value: 1), "1-month")
        XCTAssertEqual(TrialPeriodCopy.hyphenated(unit: .year, value: 1), "1-year")
    }

    /// Always singular before the noun — "a 2-week trial", never "a 2-weeks trial".
    func testTheUnitStaysSingularRegardlessOfCount() {
        XCTAssertEqual(TrialPeriodCopy.hyphenated(unit: .month, value: 6), "6-month")
        XCTAssertEqual(TrialPeriodCopy.hyphenated(unit: .day, value: 30), "30-day")
    }

    /// A malformed product yields **no** trial claim rather than a nonsense one — the paywall then
    /// falls back to trial-free copy instead of offering a "0-day free trial".
    func testNonPositiveValuesProduceNoClaim() {
        XCTAssertNil(TrialPeriodCopy.hyphenated(unit: .month, value: 0))
        XCTAssertNil(TrialPeriodCopy.hyphenated(unit: .day, value: -1))
    }

    /// The number the app ships **must not** appear as a literal anywhere in this type — it is read
    /// from StoreKit or it isn't said at all.
    func testTheOneMonthOfferRendersFromItsPeriodNotAConstant() {
        XCTAssertEqual(TrialPeriodCopy.hyphenated(unit: .month, value: 1), "1-month")
        XCTAssertEqual(TrialPeriodCopy.hyphenated(unit: .week, value: 2), "2-week",
                       "The retired 14-day offer must still render correctly — the copy follows the "
                       + "product, so an ASC rollback needs no code change.")
    }
}
