import XCTest
@testable import Pocket

/// The pure seam of the loop run driver (ADR 0046, Phase B): percent-of-original → time-stretch
/// rate. The audio playback and timer are verified on device; this pins the mapping and clamp
/// (the bit of the driver that's pure value math, AGENTS.md).
@MainActor
final class LoopRunModelTests: XCTestCase {

    func testRateIsPercentOverHundred() {
        XCTAssertEqual(LoopRunModel.rate(forPercent: 85), 0.85, accuracy: 1e-9)
        XCTAssertEqual(LoopRunModel.rate(forPercent: 100), 1.0, accuracy: 1e-9)
        XCTAssertEqual(LoopRunModel.rate(forPercent: 150), 1.5, accuracy: 1e-9)
    }

    func testRateClampsToEngineBounds() {
        // Below 0.25× and above 2.0× are pinned to the engine's playable range.
        XCTAssertEqual(LoopRunModel.rate(forPercent: 10), TempoMath.minSpeed, accuracy: 1e-9)
        XCTAssertEqual(LoopRunModel.rate(forPercent: 400), TempoMath.maxSpeed, accuracy: 1e-9)
    }
}
