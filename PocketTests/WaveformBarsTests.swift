import XCTest
@testable import Pocket

/// Display-only bar aggregation (ADR 0049) — the widen-and-smooth pass. The contract: it only
/// ever *reduces* bar count (never thins detail it doesn't have), the group size tracks the
/// target width, and the mean genuinely calms a spiky run. Pinned so a future tweak can't start
/// dropping real zoomed-in detail (AGENTS.md).
final class WaveformBarsTests: XCTestCase {

    // MARK: group size

    func testNoGroupingWhenBarsAreAlreadyWideEnough() {
        // Zoomed in (or a crisp re-downsample): source bars already ≥ target ⇒ leave them alone.
        XCTAssertEqual(WaveformBars.groupSize(sourcePitch: 5, targetPitch: 4), 1)
        XCTAssertEqual(WaveformBars.groupSize(sourcePitch: 4, targetPitch: 4), 1)
    }

    func testGroupsToReachTargetWidth() {
        // ~1px bars against a 4px target collapse ~4:1.
        XCTAssertEqual(WaveformBars.groupSize(sourcePitch: 1, targetPitch: 4), 4)
        XCTAssertEqual(WaveformBars.groupSize(sourcePitch: 2, targetPitch: 4), 2)
    }

    func testDegenerateGeometryNeverThins() {
        // A zero/negative pitch can't drive a divide — fall back to no grouping.
        XCTAssertEqual(WaveformBars.groupSize(sourcePitch: 0, targetPitch: 4), 1)
    }

    // MARK: bucketing

    func testBucketingHalvesTheCount() {
        let bars = [0.2, 0.4, 0.6, 0.8]
        let out = WaveformBars.bucketedMean(bars, group: 2)
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0], 0.3, accuracy: 1e-9)
        XCTAssertEqual(out[1], 0.7, accuracy: 1e-9)
    }

    func testTrailingBucketMayBeSmaller() {
        // 5 bars in groups of 2 ⇒ [mean(0,1), mean(2,3), lone(4)].
        let bars = [1.0, 0.0, 1.0, 0.0, 1.0]
        let out = WaveformBars.bucketedMean(bars, group: 2)
        XCTAssertEqual(out, [0.5, 0.5, 1.0])
    }

    func testGroupOfOneIsUnchanged() {
        let bars = [0.1, 0.9, 0.3]
        XCTAssertEqual(WaveformBars.bucketedMean(bars, group: 1), bars)
    }

    func testMeanCalmsASpikyRun() {
        // The reason it exists: an alternating comb flattens toward its average, killing the jitter.
        let comb = [1.0, 0.0, 1.0, 0.0]
        let out = WaveformBars.bucketedMean(comb, group: 2)
        XCTAssertEqual(out, [0.5, 0.5])
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(WaveformBars.bucketedMean([], group: 4), [])
    }
}
