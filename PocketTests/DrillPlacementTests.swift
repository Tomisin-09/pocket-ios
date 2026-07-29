import XCTest
@testable import Pocket

/// The hand-drawn drill's **placement cursor** (device feedback 2026-07-29). The failure this
/// replaces was invisible — the cursor wrapped to slot 1 at the end of the run and the next taps
/// overwrote the notes just placed, with nothing on the board to say the bar had ended — so the rule
/// is pinned here rather than left to the editor.
final class DrillPlacementTests: XCTestCase {

    private func advance(fromSlot slot: Int, slotCount: Int, barCount: Int,
                         maxBars: Int = 8) -> DrillPlacement.Advance {
        DrillPlacement.advance(fromSlot: slot, slotCount: slotCount,
                               barCount: barCount, maxBars: maxBars)
    }

    func testMidRunJustStepsForward() {
        let result = advance(fromSlot: 1, slotCount: 8, barCount: 2)
        XCTAssertEqual(result, DrillPlacement.Advance(growToBars: nil, cursor: 2))
    }

    /// The whole point: the last slot grows the run instead of wrapping over its start.
    func testTheLastSlotGrowsABarAndStepsIntoIt() {
        let result = advance(fromSlot: 3, slotCount: 4, barCount: 1)
        XCTAssertEqual(result, DrillPlacement.Advance(growToBars: 2, cursor: 4))
    }

    func testTheCursorNeverWrapsBackToTheStart() {
        for bars in 1...8 {
            let result = advance(fromSlot: bars * 4 - 1, slotCount: bars * 4, barCount: bars)
            XCTAssertNotEqual(result.cursor, 0, "\(bars) bars: filling the last slot must not wrap")
        }
    }

    /// At the ceiling there is nowhere to grow and nowhere safe to move, so the cursor holds — still
    /// not an overwrite of the run's start.
    func testAtTheBarCeilingTheCursorHolds() {
        let result = advance(fromSlot: 31, slotCount: 32, barCount: 8)
        XCTAssertEqual(result, DrillPlacement.Advance(growToBars: nil, cursor: 31))
    }

    func testASlotBeforeTheLastOneNeverGrows() {
        XCTAssertNil(advance(fromSlot: 6, slotCount: 8, barCount: 2).growToBars)
    }

    // MARK: - Degenerate inputs (total, so the editor can call it with anything)

    func testAnOutOfRangeSlotIsClampedIntoTheRun() {
        XCTAssertEqual(advance(fromSlot: 99, slotCount: 8, barCount: 2).cursor, 8)
        XCTAssertEqual(advance(fromSlot: -3, slotCount: 8, barCount: 2).cursor, 1)
    }

    func testAnEmptyRunDoesNotProduceANegativeCursor() {
        let result = advance(fromSlot: 0, slotCount: 0, barCount: 1)
        XCTAssertGreaterThanOrEqual(result.cursor, 0)
    }
}
