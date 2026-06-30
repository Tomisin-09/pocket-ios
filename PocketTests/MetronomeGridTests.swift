import XCTest
@testable import Pocket

/// Pure standalone-metronome grid math (ADR 0047). The phase-continuous re-anchor is what
/// keeps an automator step from lurching, so the splice — last queued tick stays put, next
/// tick continues at the new spacing — is pinned here (AGENTS.md).
final class MetronomeGridTests: XCTestCase {

    /// Sample of tick `index` on a grid, mirroring the engine's `subSample` rounding.
    private func tick(_ index: Int, origin: Int64, interval: Double) -> Int64 {
        origin + MetronomeGrid.frames(index, interval: interval)
    }

    // MARK: the splice

    func testLastScheduledTickKeepsItsSample() {
        // Whatever the tempo change, the already-queued tick must not move (no flush, no jump).
        let origin: Int64 = 1_000
        let scheduledThrough = 12
        let oldInterval = 22_050.0   // 120 BPM @ 44.1k
        let newInterval = 17_640.0   // 150 BPM @ 44.1k
        let lastSampleBefore = tick(scheduledThrough, origin: origin, interval: oldInterval)

        let newOrigin = MetronomeGrid.reanchoredOrigin(
            origin: origin, scheduledThrough: scheduledThrough,
            oldSubInterval: oldInterval, newSubInterval: newInterval)

        let lastSampleAfter = tick(scheduledThrough, origin: newOrigin, interval: newInterval)
        XCTAssertEqual(lastSampleAfter, lastSampleBefore)
    }

    func testNextTickContinuesAtNewSpacing() {
        let origin: Int64 = 0
        let scheduledThrough = 7
        let oldInterval = 22_050.0
        let newInterval = 17_640.0
        let lastSample = tick(scheduledThrough, origin: origin, interval: oldInterval)

        let newOrigin = MetronomeGrid.reanchoredOrigin(
            origin: origin, scheduledThrough: scheduledThrough,
            oldSubInterval: oldInterval, newSubInterval: newInterval)

        // The next unscheduled tick sits one *new* interval past the last queued one (±1 frame
        // of rounding), so the heard spacing changes exactly at the splice — no gap, no overlap.
        let nextSample = tick(scheduledThrough + 1, origin: newOrigin, interval: newInterval)
        XCTAssertEqual(Double(nextSample - lastSample), newInterval, accuracy: 1.0)
    }

    // MARK: spacing scales with tempo

    func testDoublingTempoHalvesForwardSpacing() {
        let origin: Int64 = 500
        let scheduledThrough = 4
        let oldInterval = 20_000.0
        let newInterval = 10_000.0   // twice the tempo ⇒ half the spacing

        let newOrigin = MetronomeGrid.reanchoredOrigin(
            origin: origin, scheduledThrough: scheduledThrough,
            oldSubInterval: oldInterval, newSubInterval: newInterval)

        let last = tick(scheduledThrough, origin: newOrigin, interval: newInterval)
        let next = tick(scheduledThrough + 1, origin: newOrigin, interval: newInterval)
        XCTAssertEqual(Double(next - last), newInterval, accuracy: 1.0)
    }

    // MARK: edge

    func testFirstTickReanchorIsIdentity() {
        // At tick 0 there's nothing behind the change, so the origin can't move.
        let origin: Int64 = 1_234
        let newOrigin = MetronomeGrid.reanchoredOrigin(
            origin: origin, scheduledThrough: 0,
            oldSubInterval: 22_050.0, newSubInterval: 11_025.0)
        XCTAssertEqual(newOrigin, origin)
    }
}
