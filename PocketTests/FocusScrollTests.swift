import XCTest
@testable import Pocket

/// The **growth rule** behind `scrollsIntoViewWhenFocused` (v2 close-out N5) — the one pure part of
/// keeping a growing note field above the keyboard.
///
/// It is small and it is the whole feature. Get the threshold wrong and a `TextField` shivers as its
/// layout settles by fractions of a point; drop the focus check and an unfocused field growing in
/// some other part of the form yanks the scroll view somewhere the player wasn't looking; drop the
/// direction check and deleting a line scrolls too.
final class FocusScrollTests: XCTestCase {

    func testScrollsWhenAFocusedFieldGrowsByALine() {
        // A line break is ~20 pt; anything of that order must trigger.
        XCTAssertTrue(FocusScroll.shouldScroll(from: 44, to: 64, focused: true))
    }

    func testIgnoresSubPointLayoutJitter() {
        XCTAssertFalse(FocusScroll.shouldScroll(from: 44, to: 44.4, focused: true))
        XCTAssertFalse(FocusScroll.shouldScroll(from: 44, to: 44, focused: true))
    }

    /// Shrinking already leaves the caret visible — scrolling on it would fight the collapse.
    func testIgnoresShrinking() {
        XCTAssertFalse(FocusScroll.shouldScroll(from: 64, to: 44, focused: true))
    }

    /// An unfocused field growing is somebody else's layout pass, not the caret moving.
    func testIgnoresGrowthWhileUnfocused() {
        XCTAssertFalse(FocusScroll.shouldScroll(from: 44, to: 64, focused: false))
    }

    /// The threshold is exclusive, so a change of exactly one point still counts as jitter.
    func testThresholdIsExclusive() {
        let base: CGFloat = 44
        XCTAssertFalse(FocusScroll.shouldScroll(from: base,
                                                to: base + FocusScroll.growthThreshold,
                                                focused: true))
        XCTAssertTrue(FocusScroll.shouldScroll(from: base,
                                               to: base + FocusScroll.growthThreshold + 0.1,
                                               focused: true))
    }
}
