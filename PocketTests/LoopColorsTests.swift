import XCTest
@testable import Pocket

final class LoopColorsTests: XCTestCase {

    private func interval(_ start: Double, _ end: Double) -> LoopLanes.Interval {
        LoopLanes.Interval(id: UUID(), start: start, end: end)
    }

    // MARK: Slot by start-order

    func testSlotsFollowStartOrder() {
        // Three loops in start order get slots 0, 1, 2 regardless of input order.
        let first = interval(0.1, 0.2)
        let middle = interval(0.4, 0.5)
        let last = interval(0.7, 0.8)
        let loops = [last, first, middle]   // deliberately shuffled
        XCTAssertEqual(LoopColors.slot(for: first.id, among: loops, paletteCount: 6), 0)
        XCTAssertEqual(LoopColors.slot(for: middle.id, among: loops, paletteCount: 6), 1)
        XCTAssertEqual(LoopColors.slot(for: last.id, among: loops, paletteCount: 6), 2)
    }

    func testSlotIsIndependentOfInputOrder() {
        let alpha = interval(0.0, 0.5)
        let beta = interval(0.2, 0.6)
        let gamma = interval(0.7, 0.9)
        for target in [alpha, beta, gamma] {
            let forward = LoopColors.slot(for: target.id, among: [alpha, beta, gamma], paletteCount: 6)
            let shuffled = LoopColors.slot(for: target.id, among: [gamma, alpha, beta], paletteCount: 6)
            XCTAssertEqual(forward, shuffled)
        }
    }

    // MARK: Palette wrap

    func testSlotsCycleWhenPaletteIsExhausted() {
        // Seven loops, palette of 6 → the seventh wraps back to slot 0.
        let loops = (0..<7).map { interval(Double($0) / 10, Double($0) / 10 + 0.05) }
        XCTAssertEqual(LoopColors.slot(for: loops[6].id, among: loops, paletteCount: 6), 0)
        XCTAssertEqual(LoopColors.slot(for: loops[5].id, among: loops, paletteCount: 6), 5)
    }

    // MARK: Edge cases

    func testUnknownIdReturnsZero() {
        let loops = [interval(0.1, 0.2)]
        XCTAssertEqual(LoopColors.slot(for: UUID(), among: loops, paletteCount: 6), 0)
    }

    func testEmptyPaletteReturnsZero() {
        let only = interval(0.1, 0.2)
        XCTAssertEqual(LoopColors.slot(for: only.id, among: [only], paletteCount: 0), 0)
    }

    func testTiedStartsBrokenByEndThenId() {
        // Same start; the shorter (earlier end) sorts first → slot 0.
        let identifier = UUID()
        let shortLoop = LoopLanes.Interval(id: identifier, start: 0.2, end: 0.3)
        let longLoop = interval(0.2, 0.8)
        let loops = [longLoop, shortLoop]
        XCTAssertEqual(LoopColors.slot(for: shortLoop.id, among: loops, paletteCount: 6), 0)
        XCTAssertEqual(LoopColors.slot(for: longLoop.id, among: loops, paletteCount: 6), 1)
    }

    // MARK: Manual override (ADR 0031)

    func testValidOverrideWins() {
        // First in start-order (derives slot 0) but pinned to 4 → 4.
        let first = interval(0.1, 0.2)
        let last = interval(0.7, 0.8)
        let loops = [first, last]
        XCTAssertEqual(LoopColors.resolvedSlot(override: 4, for: first.id,
                                               among: loops, paletteCount: 6), 4)
    }

    func testNilOverrideFallsBackToDerived() {
        let first = interval(0.1, 0.2)
        let last = interval(0.7, 0.8)
        let loops = [first, last]
        XCTAssertEqual(LoopColors.resolvedSlot(override: nil, for: last.id,
                                               among: loops, paletteCount: 6), 1)
    }

    func testOutOfRangeOverrideFallsBackToDerived() {
        // A stale index past the palette must not be used (no crash / blank).
        let first = interval(0.1, 0.2)
        let last = interval(0.7, 0.8)
        let loops = [first, last]
        XCTAssertEqual(LoopColors.resolvedSlot(override: 9, for: last.id,
                                               among: loops, paletteCount: 6), 1)
        XCTAssertEqual(LoopColors.resolvedSlot(override: -1, for: first.id,
                                               among: loops, paletteCount: 6), 0)
    }
}
