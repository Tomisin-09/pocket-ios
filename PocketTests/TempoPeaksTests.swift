import XCTest
@testable import Pocket

/// Pure transient-peak snapping for the downbeat handle (ADR 0024). The snap arithmetic
/// is exactly the kind that breaks silently without coverage (AGENTS.md).
final class TempoPeaksTests: XCTestCase {

    func testEmptyBarsReturnNil() {
        XCTAssertNil(TempoPeaks.snap(toFraction: 0.5, bars: [], searchRadius: 0.2))
    }

    func testNonPositiveRadiusReturnsNil() {
        XCTAssertNil(TempoPeaks.snap(toFraction: 0.5, bars: [0, 1, 0], searchRadius: 0))
    }

    func testSnapsToLoudestBarInWindow() {
        // 10 bars over [0,1] ⇒ centres 0.05, 0.15, …, 0.95. Peak at index 4 (0.45).
        let bars = [0.1, 0.1, 0.1, 0.1, 1.0, 0.1, 0.1, 0.1, 0.1, 0.1]
        let snapped = TempoPeaks.snap(toFraction: 0.5, bars: bars, searchRadius: 0.2)
        XCTAssertEqual(snapped ?? -1, 0.45, accuracy: 1e-9)
    }

    func testNoBarWithinRadiusReturnsNil() {
        // Tight radius around 0.5 catches no bar centre (nearest are 0.45 / 0.55).
        let bars = [0.1, 0.1, 0.1, 0.1, 1.0, 0.1, 0.1, 0.1, 0.1, 0.1]
        XCTAssertNil(TempoPeaks.snap(toFraction: 0.5, bars: bars, searchRadius: 0.02))
    }

    func testTieResolvesToNearestTarget() {
        // Equal peaks at index 4 (0.45) and index 6 (0.65); target 0.5 → the nearer 0.45.
        var bars = Array(repeating: 0.1, count: 10)
        bars[4] = 1.0
        bars[6] = 1.0
        let snapped = TempoPeaks.snap(toFraction: 0.5, bars: bars, searchRadius: 0.25)
        XCTAssertEqual(snapped ?? -1, 0.45, accuracy: 1e-9)
    }

    func testWindowedBarsUseCoveredRange() {
        // 3 bars covering [0.4, 0.7] ⇒ centres 0.45, 0.55, 0.65. Peak at index 1 (0.55).
        let snapped = TempoPeaks.snap(toFraction: 0.5, bars: [0.1, 1.0, 0.1],
                                      coveredStart: 0.4, coveredEnd: 0.7, searchRadius: 0.2)
        XCTAssertEqual(snapped ?? -1, 0.55, accuracy: 1e-9)
    }

    func testLoudestWinsOverNearestWhenBothInWindow() {
        // A quiet bar sits nearer the target, a louder one slightly further — louder wins.
        var bars = Array(repeating: 0.0, count: 10)
        bars[5] = 0.3   // centre 0.55, nearer target 0.52
        bars[7] = 0.9   // centre 0.75, louder
        let snapped = TempoPeaks.snap(toFraction: 0.52, bars: bars, searchRadius: 0.3)
        XCTAssertEqual(snapped ?? -1, 0.75, accuracy: 1e-9)
    }
}
