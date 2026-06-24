import XCTest
@testable import Pocket

/// `LoopProgressFormat` turns a loop's command tempo (a fraction of original) into a
/// whole-number percent and owns the `nil → "—"` unset fallback (ADR 0039). Pure tempo
/// math — the rounding boundaries break silently otherwise, so they're tested per AGENTS.md.
final class LoopProgressFormatTests: XCTestCase {

    func testPercentRoundsToWholeNumber() {
        XCTAssertEqual(LoopProgressFormat.percent(0.85), 85)
        XCTAssertEqual(LoopProgressFormat.percent(1.0), 100)
        XCTAssertEqual(LoopProgressFormat.percent(0.25), 25)
    }

    func testPercentRoundsHalvesAwayFromZero() {
        // 0.855 * 100 = 85.5 → 86; ordinary float rounding boundary.
        XCTAssertEqual(LoopProgressFormat.percent(0.855), 86)
        XCTAssertEqual(LoopProgressFormat.percent(0.824), 82)
    }

    func testPercentIsNilWhenUnset() {
        XCTAssertNil(LoopProgressFormat.percent(nil))
    }

    func testPercentLabelFormatsSetValue() {
        XCTAssertEqual(LoopProgressFormat.percentLabel(0.85), "85%")
        XCTAssertEqual(LoopProgressFormat.percentLabel(1.0), "100%")
    }

    func testPercentLabelIsEmDashWhenUnset() {
        XCTAssertEqual(LoopProgressFormat.percentLabel(nil), "—")
    }
}
