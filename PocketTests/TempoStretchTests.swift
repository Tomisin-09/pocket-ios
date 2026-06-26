import XCTest
@testable import Pocket

/// Pure stretch math (ADR 0045): the reach tempo derived from a command tempo,
/// proportional with absolute clamps, plus the backoff tail. Exercised as plain
/// values — no engine/UI — because this is exactly the tempo math that breaks
/// silently (AGENTS.md).
final class TempoStretchTests: XCTestCase {

    // MARK: - Proportional BPM target

    func testProportionalInTheUnclampedMiddle() {
        // 100 BPM × 1.06 = 106; 6 BPM increase is within [3, 15].
        XCTAssertEqual(TempoStretch.targetBPM(forCommand: 100), 106)
    }

    func testMidRangeRoundsToWholeBPM() {
        // 90 × 0.06 = 5.4 → 95.4 → 95.
        XCTAssertEqual(TempoStretch.targetBPM(forCommand: 90), 95)
    }

    func testClampsUpToMinimumIncreaseAtSlowTempos() {
        // 40 × 0.06 = 2.4 BPM, below the +3 floor → 43.
        XCTAssertEqual(TempoStretch.targetBPM(forCommand: 40), 43)
    }

    func testClampsDownToMaximumIncreaseAtFastTempos() {
        // 300 × 0.06 = 18 BPM, above the +15 ceiling → 315.
        XCTAssertEqual(TempoStretch.targetBPM(forCommand: 300), 315)
    }

    func testTargetAlwaysExceedsCommand() {
        for command in stride(from: 30, through: 320, by: 1) {
            XCTAssertGreaterThan(TempoStretch.targetBPM(forCommand: command), command,
                                 "target must reach past command at \(command) BPM")
        }
    }

    func testNonPositiveCommandReturnedUnchanged() {
        XCTAssertEqual(TempoStretch.targetBPM(forCommand: 0), 0)
    }

    // MARK: - Unit-generic core (the loop-fraction reuse path, ADR 0046)

    func testGenericTargetWorksInFractionUnits() {
        // 0.80× × 1.06 = 0.848; +0.048 within [0.02, 0.10] → 0.848.
        let reach = TempoStretch.target(forCommand: 0.80, minIncrease: 0.02, maxIncrease: 0.10)
        XCTAssertEqual(reach, 0.848, accuracy: 1e-9)
    }

    func testGenericTargetClampsInFractionUnits() {
        // 0.30× × 0.06 = 0.018, below the 0.02 floor → 0.32.
        let reach = TempoStretch.target(forCommand: 0.30, minIncrease: 0.02, maxIncrease: 0.10)
        XCTAssertEqual(reach, 0.32, accuracy: 1e-9)
    }

    // MARK: - Warm-up floor (first-open default working tempo)

    func testWarmupFloorDropsProportionallyInTheUnclampedMiddle() {
        // 96 × 0.15 = 14.4 → drop 14 → 82.
        XCTAssertEqual(TempoStretch.warmupFloorBPM(forCommand: 96), 82)
    }

    func testWarmupFloorClampsToMinimumDropAtSlowTempos() {
        // 20 × 0.15 = 3 BPM, below the 5 floor → drop 5 → 15.
        XCTAssertEqual(TempoStretch.warmupFloorBPM(forCommand: 20), 15)
    }

    func testWarmupFloorClampsToMaximumDropAtFastTempos() {
        // 200 × 0.15 = 30 BPM, above the 20 ceiling → drop 20 → 180.
        XCTAssertEqual(TempoStretch.warmupFloorBPM(forCommand: 200), 180)
    }

    func testWarmupFloorAlwaysBelowCommand() {
        for command in stride(from: 30, through: 320, by: 1) {
            XCTAssertLessThan(TempoStretch.warmupFloorBPM(forCommand: command), command,
                              "working floor must sit below command at \(command) BPM")
        }
    }

    func testWarmupFloorNonPositiveCommandReturnedUnchanged() {
        XCTAssertEqual(TempoStretch.warmupFloorBPM(forCommand: 0), 0)
    }

    // MARK: - Backoff tail

    func testBackoffMirrorsTheStretchBelowCommand() {
        // command 100, target 106 → reach is +6, so backoff is −6 → 94.
        XCTAssertEqual(TempoStretch.backoffBPM(command: 100, target: 106, floor: 60), 94)
    }

    func testBackoffNeverUndershootsTheWorkingFloor() {
        // command 70, target 76 → would be 64, but floor is 68.
        XCTAssertEqual(TempoStretch.backoffBPM(command: 70, target: 76, floor: 68), 68)
    }
}
